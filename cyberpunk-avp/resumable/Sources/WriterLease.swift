import Foundation

enum BackgroundOwnership { case idle, known(String), unknown }
private struct LeaseState: Codable { let owner_id: String; let expires: Double; let transport: String }
final class WriterLease {
    private let documents: URL
    private let clock: () -> Double
    private let fm = FileManager.default
    init(documents: URL, clock: @escaping () -> Double = { Date().timeIntervalSince1970 }) {
        self.documents = documents; self.clock = clock
    }
    private var file: URL { documents.appendingPathComponent("writer-lease.json") }
    private func read() throws -> LeaseState? {
        if !fm.fileExists(atPath:file.path), (try? fm.destinationOfSymbolicLink(atPath:file.path)) == nil { return nil }
        let attributes = try fm.attributesOfItem(atPath:file.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.size] as? NSNumber)?.intValue ?? 4097 <= 4096 else { throw ReceiverError.invalid("Invalid lease file") }
        let state = try JSONDecoder().decode(LeaseState.self,from:Data(contentsOf:file))
        guard UUID(uuidString:state.owner_id) != nil, state.expires.isFinite, state.expires > 0, ["foreground","background"].contains(state.transport) else { throw ReceiverError.invalid("Invalid lease state") }
        return state
    }
    private func check(_ owner:String) throws {
        guard UUID(uuidString:owner) != nil else { throw ReceiverError.invalid("Invalid writer identity") }
    }
    func acquire(owner:String,transport:String = "foreground",background:BackgroundOwnership) throws {
        try check(owner)
        guard ["foreground","background"].contains(transport) else { throw ReceiverError.invalid("Invalid transport") }
        let state=try read()
        switch background {
        case .unknown: throw ReceiverError.invalid("Unknown background writer")
        case .known(let pending): guard pending == owner && transport == "background" else { throw ReceiverError.invalid("Background writer busy") }
        case .idle: break
        }
        if let state, state.owner_id != owner, state.expires > clock() { throw ReceiverError.invalid("Writer busy") }
        let next=LeaseState(owner_id:owner,expires:clock()+600,transport:transport)
        try JSONEncoder().encode(next).write(to:file,options:.atomic)
        try fm.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
    }
    func validate(owner:String,transport:String? = nil,background:BackgroundOwnership = .idle) throws {
        try check(owner)
        guard let state=try read(), state.owner_id==owner else { throw ReceiverError.invalid("Writer lease missing") }
        if let transport, transport != state.transport { throw ReceiverError.invalid("Wrong writer transport") }
        if case .known(let pending)=background, pending==owner, state.transport == "background" { return } // Pending work retains ownership while off-head.
        guard state.expires>clock() else { throw ReceiverError.invalid("Writer lease expired") }
    }
    func release(owner:String,background:BackgroundOwnership) throws {
        try validate(owner:owner,background:background)
        guard case .idle=background else { throw ReceiverError.invalid("Pending background work") }
        try fm.removeItem(at:file)
    }
    func status(owner:String?) throws -> [String:Bool] {
        let state=try read()
        return ["active":state != nil && state!.expires>clock(),"owned":state?.owner_id==owner && owner != nil]
    }
    static func background(documents:URL) -> BackgroundOwnership {
        let fm=FileManager.default
        for name in ["background-transfer-plan.json","background-probe-config.json"] {
            let file=documents.appendingPathComponent(name)
            guard fm.fileExists(atPath:file.path) else { continue }
            guard let data=try? Data(contentsOf:file), data.count<=8*1024*1024,
                  let object=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else { return .unknown }
            let jobs: [[String:Any]]
            if name=="background-transfer-plan.json" {
                guard let listed=object["jobs"] as? [[String:Any]], listed.count<=10000 else { return .unknown }
                jobs=listed
            } else { jobs=[object] }
            var pending=false
            for job in jobs {
                guard let id=job["request_id"] as? String, UUID(uuidString:id) != nil else { return .unknown }
                let receipt=documents.appendingPathComponent("BackgroundReceipts/"+id+".json")
                guard let bytes=try? Data(contentsOf:receipt), bytes.count<=65536,
                      let result=(try? JSONSerialization.jsonObject(with:bytes)) as? [String:Any],
                      result["request_id"] as? String==id, result["state"] as? String=="accepted" else { pending=true;continue }
            }
            if pending {
                guard let owner=object["owner_id"] as? String, UUID(uuidString:owner) != nil,
                      jobs.allSatisfy({ $0["owner_id"] as? String==owner }) else { return .unknown }
                return .known(owner)
            }
        }
        return .idle
    }
}
