import Foundation
let fm = FileManager.default
let root = URL(fileURLWithPath: CommandLine.arguments[1])
try fm.createDirectory(at: root, withIntermediateDirectories: true)
let bytes = Data((0..<131072).map { UInt8(($0 * 17) % 251) })
let path = "Data/test.bin"
let asset = Asset(relative_path: path, bytes: UInt64(bytes.count), sha256: AssetReceiver.digest(bytes))
let manifest = AssetManifest(files: [asset])
var receiver = try AssetReceiver(root: root.appendingPathComponent("data"), manifest: manifest)
let payload = root.appendingPathComponent("chunk.bin")
func rejected(_ name: String, _ body: () throws -> Void) throws {
    do { try body() } catch { print("PASS rejected \(name)"); return }
    fatalError("Failed to reject \(name)")
}
let first = bytes.prefix(65536), second = bytes.suffix(65536)
try first.write(to: payload)
let cp = try receiver.accept(path: path, offset: 0, payload: payload, sha256: AssetReceiver.digest(first))
assert(cp.offset == 65536 && !cp.verified)
// Simulate a crash after an uncommitted write: checkpoint remains at first chunk.
let partials = try fm.contentsOfDirectory(at: root.appendingPathComponent("data/.partial"), includingPropertiesForKeys: nil)
let handle = try FileHandle(forWritingTo: partials[0]); try handle.seekToEnd(); try handle.write(contentsOf: Data(repeating: 88, count: 123)); try handle.close()
receiver = try AssetReceiver(root: root.appendingPathComponent("data"), manifest: manifest)
let resumed = try receiver.status(path: path)
assert(resumed.offset == 65536)
try second.write(to: payload)
try rejected("bad incoming hash") { _ = try receiver.accept(path: path, offset: 65536, payload: payload, sha256: String(repeating: "0", count: 64)) }
try rejected("wrong offset") { _ = try receiver.accept(path: path, offset: 0, payload: payload, sha256: AssetReceiver.digest(second)) }
try rejected("path traversal") { _ = try receiver.accept(path: "../escape", offset: 0, payload: payload, sha256: AssetReceiver.digest(second)) }
let done = try receiver.accept(path: path, offset: 65536, payload: payload, sha256: AssetReceiver.digest(second))
assert(done.verified && done.offset == UInt64(bytes.count))
let actual = try Data(contentsOf: root.appendingPathComponent("data/" + path))
assert(actual == bytes)
receiver = try AssetReceiver(root: root.appendingPathComponent("data"), manifest: manifest)
let complete = try receiver.status(path: path)
assert(complete.verified)
print("PASS restart preserves committed chunk and replaces uncommitted tail")
let final = root.appendingPathComponent("data/" + path)
try Data(repeating: 0, count: bytes.count).write(to: final)
try rejected("corrupt completed file") { _ = try receiver.status(path: path) }
try fm.removeItem(at: final)
try fm.createSymbolicLink(at: final, withDestinationURL: payload)
try rejected("symlink destination") { _ = try receiver.status(path: path) }
let small = Asset(relative_path: "Data/corrupt.bin", bytes: UInt64(bytes.count), sha256: asset.sha256)
let corruptRoot = root.appendingPathComponent("corrupt")
let corrupt = try AssetReceiver(root: corruptRoot, manifest: AssetManifest(files: [small]))
try first.write(to: payload)
_ = try corrupt.accept(path: small.relative_path, offset: 0, payload: payload, sha256: AssetReceiver.digest(first))
let partial = try fm.contentsOfDirectory(at: corruptRoot.appendingPathComponent(".partial"), includingPropertiesForKeys: nil)[0]
try Data(repeating: 0, count: first.count).write(to: partial)
try rejected("corrupt committed partial chunk") { _ = try AssetReceiver(root: corruptRoot, manifest: AssetManifest(files: [small])).status(path: small.relative_path) }
print("ALL RESUME CORE CHECKS PASSED")
