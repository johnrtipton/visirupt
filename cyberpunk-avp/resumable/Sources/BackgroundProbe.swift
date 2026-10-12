import Foundation
import SwiftUI
import UIKit

struct BackgroundProbeConfig: Codable {
    let request_id: String
    let url: String
    let token: String
    let bytes: Int
    let sha256: String
    var asset_path: String?
    var offset: UInt64?
}
struct BackgroundTransferPlan: Codable { let jobs: [BackgroundProbeConfig]; let remaining_bytes: UInt64 }
final class BackgroundProbe: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = BackgroundProbe()
    @Published var message = "Background download probe idle"
    var completionHandler: (() -> Void)?
    private let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private var timer: DispatchSourceTimer?
    private var started = Set<String>()
    private let queue = DispatchQueue(label: "local.games.background-probe")
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "local.games.cyberpunk.assetreceiver.offhead-probe")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 7*24*60*60
        config.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    private override init() {
        super.init()
        _ = session
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .seconds(1))
        timer.setEventHandler { self.checkConfig() }; self.timer = timer; timer.resume()
    }
    private func report(_ state: String, config: BackgroundProbeConfig?, extra: [String:Any] = [:]) {
        var r: [String:Any] = ["state":state, "timestamp":ISO8601DateFormatter().string(from:Date()), "game_code_executed":false]
        if let config { r["request_id"] = config.request_id }
        for (key,value) in extra { r[key] = value }
        try? JSONSerialization.data(withJSONObject:r, options:[.prettyPrinted,.sortedKeys]).write(to:documents.appendingPathComponent("background-probe-results.json"),options:.atomic)
        DispatchQueue.main.async { self.message = "Background probe: \(state)" }
    }
    private func configurations() throws -> [BackgroundProbeConfig] {
        let planURL=documents.appendingPathComponent("background-transfer-plan.json")
        if FileManager.default.fileExists(atPath:planURL.path) {
            let data=try Data(contentsOf:planURL)
            guard data.count<=8*1024*1024 else { throw ReceiverError.invalid("Oversized transfer plan") }
            let plan=try JSONDecoder().decode(BackgroundTransferPlan.self,from:data)
            guard Set(plan.jobs.map(\.request_id)).count==plan.jobs.count else { throw ReceiverError.invalid("Duplicate batch IDs") }
            return plan.jobs
        }
        return [try JSONDecoder().decode(BackgroundProbeConfig.self,from:Data(contentsOf:documents.appendingPathComponent("background-probe-config.json")))]
    }
    private func validate(_ r: BackgroundProbeConfig) throws -> BackgroundProbeConfig {
        guard UUID(uuidString:r.request_id) != nil, let url=URL(string:r.url), url.scheme=="http", url.host?.hasSuffix(".local")==true,
              url.port==8875, (url.path=="/probe" || url.path=="/asset/"+r.request_id), r.bytes > 0, r.bytes <= 256*1024*1024,
              r.token.count>=32, r.sha256.count==64, r.sha256.allSatisfy({ "0123456789abcdef".contains($0) }) else {
            throw ReceiverError.invalid("Invalid background transfer configuration")
        }
        if let path=r.asset_path, let offset=r.offset {
            let m=try JSONDecoder().decode(AssetManifest.self,from:Data(contentsOf:Bundle.main.url(forResource:"asset-manifest",withExtension:"json")!))
            guard let a=m.files.first(where:{$0.relative_path==path}), offset<=a.bytes, UInt64(r.bytes)<=a.bytes-offset else { throw ReceiverError.invalid("Invalid archive range") }
        } else {
            guard r.asset_path==nil, r.offset==nil, r.bytes==2097152, r.sha256=="be3f5187ba88afb2280fcbf18c5ffddd9af03eb5a348458b5167be7caa9b6a10" else { throw ReceiverError.invalid("Invalid synthetic fixture") }
        }
        return r
    }
    private func config(for id: String?) throws -> BackgroundProbeConfig {
        guard let r=try configurations().first(where:{$0.request_id==id}) else { throw ReceiverError.invalid("Unknown background task") }
        return try validate(r)
    }
    private func checkConfig() {
        guard let candidates=try? configurations() else { return }
        var selected: [BackgroundProbeConfig]=[]
        for candidate in candidates where !started.contains(candidate.request_id) {
            guard let c=try? validate(candidate) else { continue }
            let receipt=documents.appendingPathComponent("BackgroundReceipts/"+c.request_id+".json")
            let downloaded=documents.appendingPathComponent("BackgroundProbe/"+c.request_id+".bin")
            started.insert(c.request_id)
            if FileManager.default.fileExists(atPath:receipt.path) || FileManager.default.fileExists(atPath:downloaded.path) { continue }
            selected.append(c)
        }
        guard !selected.isEmpty else { return }
        // Conservatively reserve space for all pending downloads AND final copies.
        if candidates.count>1 {
            let remaining=candidates.reduce(UInt64(0)) {$0+UInt64($1.bytes)}
            let free=(try? FileManager.default.attributesOfFileSystem(forPath:documents.path)[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
            guard free>remaining*2+512*1024*1024 else {
                report("failed",config:nil,extra:["error":"Insufficient space for complete background batch"]);return
            }
        }
        session.getAllTasks { tasks in
            for config in selected where !tasks.contains(where:{$0.taskDescription==config.request_id}) {
                var request=URLRequest(url:URL(string:config.url)!)
                request.setValue("Bearer "+config.token,forHTTPHeaderField:"Authorization")
                let task=self.session.downloadTask(with:request)
                task.taskDescription=config.request_id
                task.resume()
            }
            self.report("batch_queued",config:selected.first,extra:["queued_tasks":selected.count])
        }
    }
    func urlSession(_ session:URLSession, downloadTask:URLSessionDownloadTask, didWriteData bytesWritten:Int64,totalBytesWritten:Int64,totalBytesExpectedToWrite:Int64) {
        let c=try? config(for:downloadTask.taskDescription)
        report("receiving",config:c,extra:["received_bytes":totalBytesWritten,"expected_bytes":totalBytesExpectedToWrite])
    }
    func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didFinishDownloadingTo location:URL) {
        do {
            let config=try config(for:downloadTask.taskDescription)
            guard downloadTask.taskDescription==config.request_id,
                  let response=downloadTask.response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode) else { throw ReceiverError.invalid("Unexpected background task response") }
            let folder=documents.appendingPathComponent("BackgroundProbe")
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let saved=folder.appendingPathComponent(config.request_id+".bin")
            try FileManager.default.moveItem(at:location,to:saved)
            let manifest=try JSONDecoder().decode(AssetManifest.self,from:Data(contentsOf:Bundle.main.url(forResource:"asset-manifest",withExtension:"json")!))
            let support=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
            let checker=try AssetReceiver(root:support.appendingPathComponent("GameData"),manifest:manifest)
            let size=(try FileManager.default.attributesOfItem(atPath:saved.path)[.size] as? NSNumber)?.intValue
            guard size==config.bytes, try checker.fileHash(saved)==config.sha256 else { throw ReceiverError.invalid("Downloaded bytes do not match") }
            if let path=config.asset_path, let offset=config.offset {
                if FileManager.default.fileExists(atPath:documents.appendingPathComponent("background-transfer-plan.json").path) {
                    ReceiverWorker.shared.processBackgroundDownloads()
                } else {
                    let command=documents.appendingPathComponent("TransferInbox/request.json")
                    guard !FileManager.default.fileExists(atPath:command.path) else { throw ReceiverError.invalid("Receiver inbox busy; downloaded file retained") }
                    let request=TransferRequest(request_id:config.request_id,action:"background_accept",path:path,offset:offset,chunk_sha256:config.sha256)
                    try JSONEncoder().encode(request).write(to:command,options:.atomic)
                }
                report("download_hash_verified_pending_commit",config:config,extra:["bytes":config.bytes,"sha256":config.sha256,"path":path,"offset":offset])
            } else { report("complete_hash_verified",config:config,extra:["bytes":config.bytes,"sha256":config.sha256]) }
        } catch { report("failed",config:try? config(for:downloadTask.taskDescription),extra:["error":String(describing:error)]) }
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,didCompleteWithError error:Error?) {
        if let error { report("failed",config:try? config(for:task.taskDescription),extra:["error":String(describing:error)]) }
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session:URLSession) {
        ReceiverWorker.shared.finishBackgroundEvents { self.completionHandler?();self.completionHandler=nil }
    }
}
final class BackgroundAppDelegate:NSObject,UIApplicationDelegate {
    func application(_ application:UIApplication,handleEventsForBackgroundURLSession identifier:String,completionHandler:@escaping ()->Void) {
        BackgroundProbe.shared.completionHandler=completionHandler
    }
}
