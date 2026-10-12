import Foundation
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let bytes = UInt64(CommandLine.arguments[2])!
let asset = Asset(relative_path: "Data/benchmark.bin", bytes: bytes, sha256: String(repeating: "0", count: 64))
let receiver = try AssetReceiver(root: root, manifest: AssetManifest(files: [asset]))
autoreleasepool {
    do { _ = try receiver.status(path: asset.relative_path); fatalError("Unexpected fixture digest") }
    catch ReceiverError.invalid(let reason) {
        precondition(reason == "Completed file hash mismatch", "Test must complete the whole hash scan")
        print("Complete synthetic hash scan exercised")
    } catch { fatalError("Unexpected fixture failure: \(error)") }
}
