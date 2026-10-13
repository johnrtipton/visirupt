import Foundation
let fm=FileManager.default
let root=URL(fileURLWithPath:CommandLine.arguments[1])
try fm.createDirectory(at:root,withIntermediateDirectories:true)
var now:Double=1000
let owner=UUID().uuidString, other=UUID().uuidString
let lease=WriterLease(documents:root,clock:{now})
func rejects(_ label:String,_ action:()throws->Void) {
    do { try action();print("FAIL \(label)");exit(1) }
    catch { print("PASS \(label)") }
}
try lease.acquire(owner:owner,background:.idle)
try lease.validate(owner:owner)
rejects("competing owner") { try lease.acquire(owner:other,background:.idle) }
now+=601
rejects("expired owner cannot write") { try lease.validate(owner:owner) }
rejects("pending background owner blocks takeover") { try lease.acquire(owner:other,background:.known(owner)) }
try lease.acquire(owner:owner,transport:"background",background:.known(owner))
try lease.validate(owner:owner,transport:"background",background:.known(owner))
rejects("foreground cannot overlap queued background") { try lease.acquire(owner:owner,transport:"foreground",background:.known(owner)) }
rejects("wrong transport cannot write") { try lease.validate(owner:owner,transport:"foreground") }
rejects("cannot release pending work") { try lease.release(owner:owner,background:.known(owner)) }
try lease.release(owner:owner,background:.idle)
rejects("unknown background blocks initial acquire") { try lease.acquire(owner:other,background:.unknown) }
try lease.acquire(owner:other,background:.idle)
let restarted=WriterLease(documents:root,clock:{now})
try restarted.validate(owner:other)
rejects("invalid owner identifier") { try restarted.acquire(owner:"not-a-uuid",background:.idle) }
try Data("corrupt lease".utf8).write(to:root.appendingPathComponent("writer-lease.json"))
rejects("corrupt persisted lease fails closed") { try restarted.acquire(owner:owner,background:.idle) }
print("ALL WRITER LEASE CHECKS PASSED")
