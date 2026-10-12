import Foundation
import CryptoKit

struct Asset: Codable { let relative_path: String; let bytes: UInt64; let sha256: String }
struct AssetManifest: Codable { let files: [Asset] }
struct TransferRequest: Codable {
    let request_id: String
    let action: String
    var path: String?
    var offset: UInt64?
    var chunk_sha256: String?
}
struct CommittedChunk: Codable { let offset: UInt64; let bytes: Int; let sha256: String }
struct AssetCheckpoint: Codable {
    var offset: UInt64 = 0
    var verified = false
    var source_sha256: String
    var chunks: [CommittedChunk] = []
}
enum ReceiverError: Error { case invalid(String) }
final class AssetReceiver {
    let root: URL
    let manifest: [String: Asset]
    let maximumChunkBytes = 256 * 1024 * 1024
    private let fm = FileManager.default
    init(root: URL, manifest: AssetManifest) throws {
        self.root = root.standardizedFileURL.resolvingSymlinksInPath()
        var entries: [String: Asset] = [:]
        for a in manifest.files {
            let parts = a.relative_path.split(separator: "/", omittingEmptySubsequences: false)
            guard !a.relative_path.hasPrefix("/"), parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }), a.sha256.count == 64,
                  a.sha256.allSatisfy({ "0123456789abcdef".contains($0) }), entries[a.relative_path] == nil else {
                throw ReceiverError.invalid("Invalid or duplicate manifest entry")
            }
            entries[a.relative_path] = a
        }
        self.manifest = entries
        try directory(self.root)
        try directory(self.root.appendingPathComponent(".checkpoints"))
        try directory(self.root.appendingPathComponent(".partial"))
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    func availableBytes() throws -> UInt64 {
        let attributes = try fm.attributesOfFileSystem(forPath: root.path)
        guard let count = attributes[.systemFreeSize] as? NSNumber else { throw ReceiverError.invalid("Cannot determine free space") }
        return count.uint64Value
    }
    private func regular(_ url: URL) throws {
        if fm.fileExists(atPath: url.path) || (try? fm.destinationOfSymbolicLink(atPath: url.path)) != nil {
            let attrs = try fm.attributesOfItem(atPath: url.path)
            guard attrs[.type] as? FileAttributeType == .typeRegular else { throw ReceiverError.invalid("Expected regular file: \(url.lastPathComponent)") }
        }
    }
    private func directory(_ url: URL) throws {
        if fm.fileExists(atPath: url.path) || (try? fm.destinationOfSymbolicLink(atPath: url.path)) != nil {
            guard try fm.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType == .typeDirectory else { throw ReceiverError.invalid("Expected directory") }
        } else { try fm.createDirectory(at: url, withIntermediateDirectories: true) }
    }
    private func destination(_ a: Asset) throws -> URL {
        var parent = root
        let parts = a.relative_path.split(separator: "/").map(String.init)
        for part in parts.dropLast() { parent.appendPathComponent(part); try directory(parent) }
        let result = parent.appendingPathComponent(parts.last!)
        try regular(result)
        return result
    }
    private func key(_ path: String) -> String { Self.digest(Data(path.utf8)) }
    private func partial(_ path: String) -> URL { root.appendingPathComponent(".partial/" + key(path)) }
    private func checkpoint(_ path: String) -> URL { root.appendingPathComponent(".checkpoints/" + key(path) + ".json") }
    private func save(_ cp: AssetCheckpoint, path: String) throws {
        let url = checkpoint(path); try regular(url)
        try JSONEncoder().encode(cp).write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url); defer { try? handle.close() }; try handle.synchronize()
    }
    func fileHash(_ url: URL, offset: UInt64 = 0, length: UInt64? = nil) throws -> String {
        try regular(url)
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        try handle.seek(toOffset: offset)
        var hash = SHA256(); var left = length
        while left == nil || left! > 0 {
            let count = Int(min(left ?? 1048576, 1048576))
            // Foundation's bridged NSData buffers otherwise remain autoreleased
            // until the entire dispatch block ends, retaining a whole large file.
            let received: Int = try autoreleasepool {
                let data = try handle.read(upToCount: count) ?? Data()
                hash.update(data: data)
                return data.count
            }
            if received == 0 { if let left, left > 0 { throw ReceiverError.invalid("Truncated committed data") }; break }
            if left != nil { left! -= UInt64(received) }
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    func status(path: String) throws -> AssetCheckpoint {
        guard let a = manifest[path] else { throw ReceiverError.invalid("Path is absent from manifest") }
        let final = try destination(a)
        if fm.fileExists(atPath: final.path) {
            let size = (try fm.attributesOfItem(atPath: final.path)[.size] as? NSNumber)?.uint64Value
            guard size == a.bytes, try fileHash(final) == a.sha256 else { throw ReceiverError.invalid("Completed file hash mismatch") }
            let cp = AssetCheckpoint(offset: a.bytes, verified: true, source_sha256: a.sha256)
            try save(cp, path: path); return cp
        }
        let stateURL = checkpoint(path); try regular(stateURL)
        guard fm.fileExists(atPath: stateURL.path) else { return AssetCheckpoint(source_sha256: a.sha256) }
        let cp = try JSONDecoder().decode(AssetCheckpoint.self, from: Data(contentsOf: stateURL))
        guard cp.source_sha256 == a.sha256, cp.offset <= a.bytes, !cp.verified else { throw ReceiverError.invalid("Checkpoint source mismatch") }
        var end: UInt64 = 0
        for chunk in cp.chunks {
            guard chunk.offset == end, chunk.bytes > 0, chunk.bytes <= maximumChunkBytes,
                  UInt64(chunk.bytes) <= a.bytes - end,
                  try fileHash(partial(path), offset: end, length: UInt64(chunk.bytes)) == chunk.sha256 else { throw ReceiverError.invalid("Committed chunk mismatch") }
            end += UInt64(chunk.bytes)
        }
        guard end == cp.offset else { throw ReceiverError.invalid("Invalid checkpoint offset") }
        return cp
    }
    // status() verifies persisted bytes after process restart. Caller may retain this
    // verified checkpoint only within its exclusive serial receiver session.
    func accept(path: String, offset: UInt64, payload: URL, sha256: String, previous: AssetCheckpoint? = nil) throws -> AssetCheckpoint {
        guard let a = manifest[path] else { throw ReceiverError.invalid("Unknown asset") }
        var cp = try previous ?? status(path: path)
        guard cp.source_sha256 == a.sha256, !cp.verified, offset == cp.offset, offset <= a.bytes else { throw ReceiverError.invalid("Unexpected chunk offset") }
        try regular(payload)
        let size = (try fm.attributesOfItem(atPath: payload.path)[.size] as? NSNumber)?.uint64Value ?? 0
        guard size > 0, size <= UInt64(maximumChunkBytes), size <= a.bytes - offset else { throw ReceiverError.invalid("Invalid chunk size") }
        guard try fileHash(payload) == sha256 else { throw ReceiverError.invalid("Incoming chunk hash mismatch") }
        guard try availableBytes() > size + 512 * 1024 * 1024 else { throw ReceiverError.invalid("Insufficient disk space; saved checkpoint retained") }
        let target = partial(path); try regular(target)
        if !fm.fileExists(atPath: target.path) { guard fm.createFile(atPath: target.path, contents: nil) else { throw ReceiverError.invalid("Cannot create partial file") } }
        let input = try FileHandle(forReadingFrom: payload); defer { try? input.close() }
        let output = try FileHandle(forWritingTo: target); defer { try? output.close() }
        try output.truncate(atOffset: offset); try output.seek(toOffset: offset)
        while try autoreleasepool(invoking: {
            guard let data = try input.read(upToCount: 1048576), !data.isEmpty else { return false }
            try output.write(contentsOf: data)
            return true
        }) {}
        try output.synchronize()
        guard try fileHash(target, offset: offset, length: size) == sha256 else { throw ReceiverError.invalid("Written chunk hash mismatch") }
        cp.chunks.append(CommittedChunk(offset: offset, bytes: Int(size), sha256: sha256)); cp.offset += size
        if cp.offset == a.bytes {
            guard try fileHash(target) == a.sha256 else { throw ReceiverError.invalid("Complete original asset SHA256 mismatch") }
            let final = try destination(a)
            try fm.moveItem(at: target, to: final)
            cp.verified = true
        }
        try save(cp, path: path)
        return cp
    }
}
