import SwiftUI
import Foundation

final class ReceiverWorker: ObservableObject {
    static let shared = ReceiverWorker()
    @Published var message = "Starting asset receiver"
    private let queue = DispatchQueue(label: "local.games.assetreceiver", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var receiver: AssetReceiver?
    private var cache: [String: AssetCheckpoint] = [:]
    private var lastRequest = ""
    private let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private func publish(_ message: String) { DispatchQueue.main.async { self.message = message } }
    init() {
        queue.async {
            do {
                guard let manifestURL = Bundle.main.url(forResource: "asset-manifest", withExtension: "json") else { throw ReceiverError.invalid("Manifest resource missing") }
                let manifestData = try Data(contentsOf: manifestURL)
                guard manifestData.count <= 8 * 1024 * 1024 else { throw ReceiverError.invalid("Manifest resource too large") }
                let manifest = try JSONDecoder().decode(AssetManifest.self, from: manifestData)
                let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                var root = support.appendingPathComponent("GameData")
                self.receiver = try AssetReceiver(root: root, manifest: manifest)
                var attributes = URLResourceValues(); attributes.isExcludedFromBackup = true
                try root.setResourceValues(attributes)
                try FileManager.default.createDirectory(at: self.documents.appendingPathComponent("TransferInbox"), withIntermediateDirectories: true)
                self.drainBackgroundDownloads()
                self.publish("Asset receiver ready\nVerified chunks survive restart\nNo game code executed")
                let timer = DispatchSource.makeTimerSource(queue: self.queue)
                timer.schedule(deadline: .now(), repeating: .seconds(1))
                timer.setEventHandler { self.consume(); self.drainBackgroundDownloads() }; self.timer = timer; timer.resume()
            } catch { self.publish("Receiver setup failed: \(error)") }
        }
    }
    // URLSession's background completion must wait for the serial checkpoint
    // commit; returning it first lets visionOS suspend the polling timer.
    func finishBackgroundEvents(completion: @escaping () -> Void) {
        queue.async {
            self.consume()
            self.drainBackgroundDownloads()
            DispatchQueue.main.async { completion() }
        }
    }
    func processBackgroundDownloads() { queue.async { self.drainBackgroundDownloads() } }
    private func drainBackgroundDownloads() {
        guard let receiver, let data=try? Data(contentsOf:documents.appendingPathComponent("background-transfer-plan.json")),
              data.count<=8*1024*1024, let plan=try? JSONDecoder().decode(BackgroundTransferPlan.self,from:data) else { return }
        let jobs=plan.jobs.sorted { ($0.asset_path ?? "",$0.offset ?? 0)<($1.asset_path ?? "",$1.offset ?? 0) }
        let receipts=documents.appendingPathComponent("BackgroundReceipts")
        do { try FileManager.default.createDirectory(at:receipts,withIntermediateDirectories:true) } catch { publish("Cannot create batch receipts: \(error)");return }
        for job in jobs {
            guard UUID(uuidString:job.request_id) != nil, let path=job.asset_path, let offset=job.offset else { continue }
            let payload=documents.appendingPathComponent("BackgroundProbe/"+job.request_id+".bin")
            let receipt=receipts.appendingPathComponent(job.request_id+".json")
            guard FileManager.default.fileExists(atPath:payload.path), !FileManager.default.fileExists(atPath:receipt.path) else { continue }
            guard let owner=plan.owner_id, job.owner_id==owner else { continue }
            do { try WriterLease(documents:documents).validate(owner:owner,transport:"background",background:WriterLease.background(documents:documents)) } catch { continue }
            var result: [String:Any]=["request_id":job.request_id,"path":path,"game_code_executed":false]
            do {
                let old=try cache[path] ?? receiver.status(path:path)
                cache[path]=old
                if old.offset<offset { continue } // Completed downloads may arrive out of order.
                let cp: AssetCheckpoint
                if old.verified || old.chunks.contains(where:{$0.offset==offset && $0.bytes==job.bytes && $0.sha256==job.sha256}) { cp=old }
                else { cp=try receiver.accept(path:path,offset:offset,payload:payload,sha256:job.sha256,previous:old) }
                cache[path]=cp
                result["state"]="accepted"
                result["checkpoint"]=try JSONSerialization.jsonObject(with:JSONEncoder().encode(cp))
                try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys]).write(to:receipt,options:.atomic)
                try FileManager.default.removeItem(at:payload)
                publish("Background transfer: \(path)\n\(cp.offset) verified bytes")
            } catch {
                result["state"]="rejected";result["error"]=String(describing:error)
                try? JSONSerialization.data(withJSONObject:result,options:[.sortedKeys]).write(to:receipt,options:.atomic)
                publish("Background commit rejected: \(error)")
            }
        }
    }
    private func consume() {
        guard let receiver else { return }
        let inbox = documents.appendingPathComponent("TransferInbox")
        let command = inbox.appendingPathComponent("request.json")
        guard let data = try? Data(contentsOf: command), data.count <= 65536,
              let request = try? JSONDecoder().decode(TransferRequest.self, from: data),
              !request.request_id.isEmpty, request.request_id.count <= 128,
              request.request_id != lastRequest else { return }
        lastRequest = request.request_id
        var result: [String: Any] = ["request_id": request.request_id, "game_code_executed": false]
        do {
            let lease=WriterLease(documents:documents)
            let background=WriterLease.background(documents:documents)
            if request.action == "lease_status" {
                result["lease"] = try lease.status(owner:request.owner_id)
            } else if request.action == "lease_acquire", let owner=request.owner_id {
                try lease.acquire(owner:owner,transport:request.transport ?? "",background:background)
            } else if request.action == "lease_release", let owner=request.owner_id {
                try lease.release(owner:owner,background:background)
            } else if request.action == "status", let owner=request.owner_id {
                try lease.validate(owner:owner,background:background)
                self.publish("Verifying saved transfer progress")
                cache = [:]
                for path in receiver.manifest.keys.sorted() { cache[path] = try receiver.status(path: path) }
                result["files"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(cache))
                result["available_disk_bytes"] = try receiver.availableBytes()
            } else if (request.action == "accept" || request.action == "background_accept"), let path = request.path, let offset = request.offset, let hash = request.chunk_sha256, let owner=request.owner_id, let bytes=request.bytes {
                try lease.validate(owner:owner,transport:request.action=="background_accept" ? "background" : "foreground",background:background)
                guard let asset=receiver.manifest[path], bytes>0, bytes<=256*1024*1024,
                      offset<=asset.bytes, bytes<=asset.bytes-offset else { throw ReceiverError.invalid("Invalid request range") }
                let payload = request.action == "background_accept" ? documents.appendingPathComponent("BackgroundProbe/" + request.request_id + ".bin") : inbox.appendingPathComponent("payload.bin")
                guard UUID(uuidString: request.request_id) != nil else { throw ReceiverError.invalid("Invalid request ID") }
                let old = try cache[path] ?? receiver.status(path: path)
                let cp: AssetCheckpoint
                if old.verified || old.chunks.contains(where: { $0.offset == offset && $0.bytes == Int(bytes) && $0.sha256 == hash }) {
                    cp = old // A replay of an already verified chunk is harmless.
                } else { cp = try receiver.accept(path: path, offset: offset, payload: payload, sha256: hash, previous: old) }
                cache[path] = cp
                result["path"] = path
                result["checkpoint"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(cp))
                result["asset_root"] = receiver.root.path
                self.publish("\(path)\n\(cp.offset) verified bytes\n\(cp.verified ? "File complete" : "Transfer checkpoint saved")")
                try? FileManager.default.removeItem(at: payload)
            } else { throw ReceiverError.invalid("Unsupported command") }
            result["state"] = "accepted"
        } catch { result["state"] = "rejected"; result["error"] = String(describing: error); self.publish("Transfer rejected: \(error)") }
        do {
            try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(to: documents.appendingPathComponent("transfer-results.json"), options: .atomic)
            try? FileManager.default.removeItem(at: command)
        } catch { self.publish("Cannot save transfer receipt: \(error)") }
    }
}
@main struct AssetReceiverApp: App {
    @UIApplicationDelegateAdaptor(BackgroundAppDelegate.self) private var appDelegate
    @StateObject private var worker = ReceiverWorker.shared
    @StateObject private var backgroundProbe = BackgroundProbe.shared
    var body: some Scene { WindowGroup { VStack(spacing: 18) {
        Text("Cyberpunk Asset Receiver").font(.title)
        Text(worker.message).textSelection(.enabled)
        Text(backgroundProbe.message).font(.caption)
    }.padding(30).frame(minWidth: 520, minHeight: 260) } }
}
