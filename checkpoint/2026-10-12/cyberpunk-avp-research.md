## Responsive native1280x720 baseline accepted — October 12, 2026

Human confirms the combined arrow-turn/WASD hold-release test works well and is very responsive. Native original-engine trace now measures1280x720 output drawables, compared with640x360 in the previous plain-window build: four times the output pixel count. This is real native drawable evidence, not inference from a saved preference or larger window. Internal scene render targets, measured FPS/frame-time and extended stability remain unmeasured.

The last observed game layer2036x1145 still presents a1280x720 drawable; resizing can enlarge its presentation but dynamic backing render resolution does not yet track window size. Current playable build is plain/black/rectangular-hit-region and resizable, has WASD movement and left/right-arrow horizontal camera turning, plus Space/Return/Escape and pointer click/look/fire/drag/trackpad scroll. One native input XML was intentionally modified for arrow turning; original backup and verified modified SHA retained. All archive binaries remain unchanged.

Native windowed gameplay is now a confirmed baseline on M2 Vision Pro. Immersive stereo VR, head/controller tracking and performance characterization are separate next milestones. Current installed/confirmed PID3408 build remains running; no additional installation or process interruption performed after acceptance. Evidence: scratch/cyberpunk-input/arrow-evidence.json and scratch/cyberpunk-render-resolution/evidence.json under `/Users/tip/Dropbox/online_projects/ai/games`.

## Arrow-key camera turning prepared — October 12, 2026

User requested swivel left/right on arrow keys, interpreted as camera yaw while WASD remains movement. Shipped inputContexts.xml maps CameraMovement.CameraX to RightX_Axis; shipped FreeCam_RightX_Axis already maps IK_Left=-1 and IK_Right=1. Added the same two buttons to the normal RightX_Axis, keeping the original pad button. Native UIKit left/right arrows map to Mac keycodes123/124 with actual down/up callbacks. No simulated pointer location or mouse warp is used.

Original headset inputUserMappings.xml is backed up. Modified XML parses and differs only by the two-button insertion; original/modified SHA256 values recorded. This intentionally changes one active native input configuration, so its prior original-file transfer checksum no longer describes that modified file. All archive binaries and original local source remain untouched. All 95 adapter-only simulator checks pass; actual camera-turn behavior is pending physical acceptance.

Same build includes the prepared1280x720 initial-window resolution experiment; actual drawable pixels must be checked after launch. Original engine and stereo VR camera changes are not part of this update. Evidence under `/Users/tip/Dropbox/online_projects/ai/games/scratch/cyberpunk-input/arrow-evidence.json`; preserve receiver data, never uninstall.

## Plain resizable gameplay accepted; actual 640x360 output — October 12, 2026

Human confirms the black rectangular hit region makes the plain window playable and resizable. Reports very low resolution and asks for improved bindings, while reiterating that the goal is VR. Existing WASD, Space/Return/Escape, pointer look/fire/click/drag/scroll are a limited flat-game test interface; stereo VR, head/controller tracking and complete bindings remain separate work.

Native original-engine trace shows all 50 sampled phase2 drawables at 640x360. Later native UI observation has game layer1414x795 and window1414x821, while drawable remains640x360. Thus physical window resizing has expanded the presentation without raising backing render resolution. Saved game Resolution is1280x720; ResolutionScaling=Off and DynamicResolutionScaling=false. Saved preference is not actual render-resolution proof. Internal GPU render target dimensions and FPS were not measured.

Prepared controlled test changes only default initial native window to1280x720, retaining minimum640x360, plain style, black hit region and working input. Native mode/geometry startup influences the original renderer; physical drawables must be checked before saying quality improved. Known playable640 host source backed up under scratch/cyberpunk-render-resolution in `/Users/tip/Dropbox/online_projects/ai/games`. Native assets and saved data remain intact. Dynamic render-buffer reconfiguration on window resize is still unresolved.

## Plain-window pointer-entry regression — October 12, 2026

Human reports plain appearance improved but trackpad pointer cannot enter, preventing startup. Device game-load result confirms WAITING_FOR_NATIVE_POINTER_SAMPLE, native pointer availability0, original engine entrypoint not issued (runD49D09E8-743A-4443-90C2-DF10D6EF73ED). This is an input-entry regression, not evidence of a game crash or asset failure. Resize acceptance is still unverified.

Prepared and installed the minimal interaction-area test: black SwiftUI background and rectangular contentShape on the full flexible host content, retaining plain window style and resizing. This tests transparent plain-surface hit-region admission as the cause; physical acceptance remains pending. No fake pointer sample or startup-readiness bypass. Native host build/signature pass. Evidence and launch/install results under scratch/cyberpunk-window-presentation in `/Users/tip/Dropbox/online_projects/ai/games`. All assets/saved data retained; never uninstall.

## Playable keyboard/mouse build; plain resizable window — October 12, 2026

Human confirmed WASD movement starts while held and stops on release, and describes native Cyberpunk as playable in a larger planar window. Aiming, firing, scrolling, keyboard/click input and movement have now received human confirmation. Extended stability and measured performance remain untested; this is not stereo immersive VR.

Requested a borderless resizable window. The existing scene used default glass-backed WindowGroup, and game content retained its own fixed size inside the larger host. Prepared host changes: plain windowStyle removes glass backing; explicit contentMinSize resizability; 640x360 minimum/default 16:9 initial geometry; flexible content sizing; hide diagnostic label when original engine starts. Native scene layout changes resize the real game NSWindow via its existing aspect/minimum/layout and actual resize notification path. No original engine binary or assets changed. Previously remembered system window size may override defaultSize.

Native host build passed. Physical plain-window appearance and resize rendering/input alignment require acceptance. Existing 94 simulator adapter checks previously passed; no new simulator gameplay or UI-resize acceptance is claimed. Source backups, scripts and evidence are under `/Users/tip/Dropbox/online_projects/ai/games/scratch/cyberpunk-window-presentation`; runtime host remains `/Users/tip/games/scratch/cyberpunk-staged-startup`. Preserve receiver app data, never uninstall.

## Native gameplay confirmed on M2 Vision Pro — October 12, 2026

Human reports scrolling works well and they are in actual gameplay: can fire, look around and play. This confirms native gameplay beyond startup video and the terms screen. It remains a native visionOS window; stereo immersive VR, controller input, measured performance and extended stability are not established.

Walking was unavailable because the native keyboard adapter mapped only Space/Return/Escape. Added WASD using local Apple SDK Mac keycodes W=13, A=0, S=1, D=2 through existing real UIKit press callbacks. Native key down/up and cancelled release are delivered through the original event queue. Simulator reproduced absent mappings first; all 94 final adapter-only controls pass. Physical movement confirmation remains pending. Movement controls: hold W forward, S backward, A left, D right; Space is already mapped. These are normal key inputs, not game-state manipulation.

Evidence: `scratch/cyberpunk-input/gameplay-evidence.json` under `/Users/tip/Dropbox/online_projects/ai/games`. Runtime sources/builds remain `/Users/tip/games`. All original asset archives and receiver app data preserved; no uninstall. Do not call simulator controls gameplay benchmarks.

## Terms screen reached; scroll and drag adapter — October 12, 2026

Human confirmed native keyboard and mouse clicks work and the game renders its terms screen. This advances beyond intro playback. Trackpad scroll and dragging did not work. No terms acceptance, menu, 3D gameplay or VR is yet confirmed.

Missing paths were native touchesMoved translation and scroll recognition/dispatch. Added held-primary-button movement to mouseDragged and a continuous trackpad UIPanGestureRecognizer to precise scrollWheel. The scroll recognizer uses an empty allowedTouchTypes list and does not cancel touches, preserving separate click/drag delivery. Scroll translation resets each callback; observed pan phases are retained, with no distinct momentum phase claimed. No terms or consent bypass was added.

All 92 final adapter-only simulator checks pass, including native coordinate/delta preservation, actual event dispatch, recognizer configuration, unheld movement rejection, zero-delta handling and scroll-end phase. Fixtures do not execute original game code. Native trackpad gesture delivery and direction still require physical acceptance. Evidence: `scratch/cyberpunk-input/scroll-evidence.json` under `/Users/tip/Dropbox/online_projects/ai/games`. Runtime sources/builds remain `/Users/tip/games`. Same asset receiver ID; preserve archives, never uninstall.

## Full native intro and initial input support — October 12, 2026

Human confirmed the full real Cyberpunk intro plays on M2 Vision Pro and pointer movement works after the pointer-exit fix. Click and Space did not advance. This establishes sustained intro-video playback, not menu rendering, gameplay or VR.

Inspection found native hover translation only, with no button/keyboard callback handling. Added primary click down/up through real UIKit touch callbacks and Space/Return/Escape through real hardware-key callbacks, mapped to Mac keycodes 49/36/53. Native coordinates, timestamps, modifiers and supplied text/tap count are preserved. Unsupported keys remain with UIKit; secondary pointer clicks are not represented as primary. Cancelled primary clicks release the button. Translation and original-game dispatch use the existing event queue. A bounded log stores event type/code/timestamp only, not typed text.

Simulator reproduced missing click and Space first; all 83 final adapter-only checks pass, including dispatch, key mapping, metadata, secondary rejection and cancellation. The timer fixture now allows eight immediate nonblocking polls because UIKit focus sources may run before due timers; the future-timer no-wait check remains. Original game code does not run in this fixture. Device visual/input acceptance remains pending. Evidence and temporary scripts: `scratch/cyberpunk-input/` in `/Users/tip/Dropbox/online_projects/ai/games`. Runtime sources/builds remain in `/Users/tip/games`; the workspace relocation did not move them. Preserve receiver app data and never uninstall.


Pointer-exit correction: simulator regression first failed on the known exit position; final 73 checks pass, including querying within mouseExited itself. Native pointer observations now retain the actual exit coordinate within the same live scene; no invented position and no promise of system-global cursor tracking. Device build and deep/strict signature verification passed; physical retest pending.
## First native Cyberpunk startup video — October 12, 2026

Human confirmed the real game startup video on M2 Vision Pro for about five seconds, then the app closed. Recognizable game music and dialogue were also confirmed. Native first visible game video is achieved; stable startup, menu, 3D gameplay, performance and immersive VR remain unverified.

Window frame origins now reconcile Cocoa bottom-left coordinates with real UIKit geometry. UI-published immutable NSScreen numeric snapshots allow worker queries without worker UIKit access. Process-local forwarding diagnostics observe actual Metal drawables, presentation and GPU completion without fabricating results. The original engine's expired-deadline event polls had starved UIKit; servicing already-ready native run-loop work and flushing real layer transactions restored UI heartbeat and produced the visible video. All 72 adapter-only simulator controls passed before this physical test; they do not run original game code.

Matching crash PID3303 at 13:55:25 reports SIGABRT in NSEvent.mouseLocation during the real mouseExited callback. The adapter discarded its observed native pointer sample before dispatching exit. A simulator regression reproduces this. Next action: validate observed exit-position retention in the same connected native scene, then update the same app without uninstalling or recopying assets.

A prior delayed LLDB attach interrupted PID3251 while cancellation was underway; no clean successful detach is claimed. Subsequent diagnostics are in-app. Original experimental pool-capacity module and all 110 verified original asset files are preserved. Evidence: `/Users/tip/games/cyberpunk-avp/research/first-native-startup-video-2026-10-12.json`.

## Morning device retest — October 12, 2026

## Scene timing and windowed startup — October 12, 2026

Added NSScreen minimum/maximumRefreshInterval from one real scene-specific CADisplayLink duration. Both describe the port's single observed backing cadence; this explicitly does not claim headset panel capabilities or variable-refresh negotiation. Before sampling, queries raise an explicit error. Engine startup waits for actual timing and pointer readiness. Simulator timing controls passed and physical run 4B3CD73A-82D7-4ECE-9935-53408F8892DD (PID3172) observed 0.011111125 seconds with both getters passing.

That run advanced to toggleFullScreen: at original return0x103c83b30. Its original WaitForCompletion: relies on genuine fullscreen delegate transitions, so no no-op method or fake completion was added. A normal missing user setting was created instead: Mac version138, /video/display WindowMode=Windowed index0. Native open of UserSettings.json returned descriptor12. Run CC186284-C2F3-409D-ABF3-A2D1C09E8253 (PID3182) accepted the setting and requested normal constructor style15; the strict constructor then rejected it. Added explicit native-scene-chrome policy for audited style0/15 requests, with actual desktop style bits still0 and unknown styles rejecting.

The subsequent no-click normal-window run (PID3189) reached setMinSize:, proving a click was not necessary for closure. Added real minimum native content bounds, resize clamping, aspect preservation, reset and invalid-size rejection. Minimum-size run 1E1FF00E-3194-4B1D-9B1D-B931D35B4CFC (PID3196) advanced to setContentSize:. Added real resizing through the existing frame/layout/notification path. All 56 source-only simulator controls passed. Device build/install/launch results and the final content-size run are recorded in the evidence JSON. These fixture controls do not execute original game code or establish a rendered game frame.

Existing settings are preserved; the preference helper only creates a missing file. No original game code or asset archive changed in this work. Same receiver bundle ID and native assets retained; never uninstall. Native fullscreen remains unsupported. Evidence: `/Users/tip/games/cyberpunk-avp/research/refresh-windowed-startup-validation-2026-10-12.json`. Inspect the latest content-size crash/result before deciding the next adapter. There is still no confirmed Cyberpunk frame or VR gameplay.

Latest content-size physical run BFA5823D-F06F-477C-8613-121D37F7974D (PID3202) advanced to setFrameOrigin: at return0x103c87720. Matching crash13:03:08 is recorded. Next geometry adapter must reconcile Cocoa screen-origin semantics with native content/container geometry; do not fabricate a desktop offset or merely store a position flag. Current installed app is the content-size version, normal Windowed preference persists, and the receiver asset container remains preserved. No further physical launch after this result. Final device build and deep/strict signature checks passed; own simulator fixture terminated after results.


## Native pointer startup tests — October 12, 2026

Physical coordinate run C415D457-8784-4016-AEE1-2EFC16815E0D (PID3135) passed both native coordinate controls and loaded the game graph. The engine advanced past coordinate conversion, then aborted on the class method `NSEvent.mouseLocation`, statically decoded at return 0x103c84b30. Added live UIKit hover sampling in the registered scene with explicit unavailable errors before sampling or after hover exit. The host waits for a real trackpad sample before original startup.

The user physically moved the paired trackpad, triggering engine run A343C74D-D0AB-4546-972F-2BC32F9A7EDF (PID3140). Its native screen point was (190.0403, 710.5000). The window then closed; the matching crash advanced to `NSEvent.setMouseCoalescingEnabled:NO`, decoded at return 0x103c840e4. The host queue already retains every delivered motion callback individually. Added the disabling contract plus a truthful false getter; enabling coalescing is explicitly rejected. This does not change UIKit's upstream sampling rate.

Physical coalescing run 776C76B8-F2D2-4ADD-BD41-97D51E38D85C (PID3147) advanced past that call and aborted on `NSWindow.setIsVisible:YES` at return 0x103c87008. Its native pointer sample was (688.5549, 710.5001). The bounded following calls were audited: makeMainWindow, makeKeyAndOrderFront, firstResponder. Added actual native content show/hide and explicit primary-window selection separately from key focus. Detached show requests explicitly reject.

All 42 source-only simulator controls passed, including actual visibility and main/key separation, separate ordered hover events, root/child pointer conversion, no-sample and hover-exit rejection, and the previous geometry/input controls. No original game code ran in the simulator. The signed device host built, installed normally with the same asset receiver ID, and passed deep/strict signature verification. No assets were uninstalled or retransferred. The latest device run is captured in the evidence JSON; inspect its startup and crash fields for the final result.

There is still no confirmed first game frame or VR gameplay. Evidence: `/Users/tip/games/cyberpunk-avp/research/native-pointer-startup-validation-2026-10-12.json`. Next work must follow the matching latest-run crash or actual frame evidence; preserve the receiver's native asset container.

Latest visibility run BC044CC7-444E-44CB-868C-76F128A638E6 (PID3152) used real pointer (1270.4998, 328.0149), stayed running temporarily, and later aborted. User confirmed no Cyberpunk image. Matching crash 12:40:04 decoded to NSScreen.minimumRefreshInterval at return 0x103535854; the following maximumRefreshInterval getter is compared to detect variable refresh. This is another real graphics setup contract, not a confirmed frame. Current installed app is the visibility version. Next: obtain an authentic native scene cadence/range contract before adding refresh getters; do not invent physical headset rates or treat a preferred display-link rate as measured capability. No additional launch after this result.


## Off-head coordinate adapter validation — October 12, 2026

Implemented `NSWindow.convertPointToScreen:` and its inverse using actual UIKit view ancestry. Cocoa bottom-left points are flipped to UIKit coordinates and back around the real content and registered viewport bounds. Values stay in points; this is the port-local scene viewport, not a fabricated macOS desktop. Detached windows and non-finite points explicitly raise errors.

The source-only visionOS simulator fixture first reproduced the missing selector with all prior 17 checks passing. After the implementation, all 31 checks passed, including known nested offsets, corner orientation, fractional and off-bounds points, inverse conversion, roundtrip, resize/move tracking, invalid points and detached windows. Safe-area geometry and separate main/key-window roles also passed. Controlled hover samples are not physical trackpad acceptance; no original Cyberpunk code ran in this fixture.

The signed device host includes two coordinate controls before engine startup. Its build and deep/strict signature verification passed. No physical install or launch occurred after the user took off the headset. Existing native assets remain preserved. There is still no confirmed game frame or VR gameplay.

Evidence: `/Users/tip/games/cyberpunk-avp/research/window-coordinate-validation-2026-10-12.json`. Prepared app: `/Users/tip/games/scratch/cyberpunk-staged-startup/DerivedData/Build/Products/Debug-xros/CyberpunkStartupFileProbe.app`.

Next headset session: normal update of `local.games.cyberpunk.assetreceiver` (never uninstall), then one original-engine launch. Inspect the coordinate control results, run UUID and matching crash/frame evidence. Do not rebuild the separate full-asset startup-file-probe bundle or restart asset transfer.


The prepared build installed and ran with the original assets preserved. Native SDR, aspect/resize and delegate controls passed. Original startup reached tracking-area setup, then aborted on NSView.safeAreaRect. We added a real UIKit bounds/safe-area-inset adapter; its physical check passed and startup advanced.

The next missing method was NSApplication.mainWindow. The adapter now tracks a weak primary visible native window separately from the current key window. Physical tests passed registration, primary/key separation across two real native content windows, and clearing after close. The dependency graph continues to load successfully.

The latest original-engine attempt then aborted on NSWindow.convertPointToScreen:. Native content-to-registered-viewport coordinate conversion, including coordinate orientation and inverse/round-trip checks, is the next task. No game frame is confirmed. The current installed app contains the safe-area and main-window fixes and retains the same verified game-data container.

Evidence: /Users/tip/games/cyberpunk-avp/research/morning-startup-validation-2026-10-12.json . Raw device results and matching crash reports: /Users/tip/games/scratch/cyberpunk-staged-startup/ . Do not uninstall or recopy assets.

## Window initialization adapters and simulator validation — October 12, 2026

Physical startup tests cleared the HDR-query, screen-specific window constructor, aspect-ratio and window-delegate gaps. The engine requested a real 640×360 borderless, buffered window on the registered viewport. Native attachment, 16:9 content geometry after resizing, weak delegate registration, and real resize/close callback delivery passed their scoped tests. No game frame has been shown.

The host now deliberately supports SDR output: its port-local screen range is 1.0, and attached native layers use standard dynamic range, no extended-range content and content headroom 1.0. This is an explicit viewport limit, not a measurement of the headset's HDR panels. The SDK rejects UIWindowScene.screen on visionOS; that unavailable query approach was not deployed.

An audit of the same original window-init routine identified desktop fullscreen eligibility (128), cursor-location assistance suppression (4096), screen lookup and mouse-move setup. The latest adapter records unsupported desktop policy requests while reporting actual supported options as zero; it keeps real windowed presentation. Screen lookup resolves the attached native scene. Actual UIHoverGestureRecognizer callbacks now translate into queued mouse-moved events, gated by window visibility, key state and acceptsMouseMovedEvents; content dispatch is implemented.

After the user removed the headset for bed, physical operations stopped. A separate source-only visionOS simulator app passed all 17 checks for native view/window attachment, SDR layers, aspect/resize behavior, callback delivery, weak ownership, unsupported-policy reporting, rejected invalid settings, controlled hover-to-event translation/dispatch and detachment. The hover tests use synthesized recognizer samples through the native view path; they are not physical trackpad acceptance. Original game code did not run in this simulator test.

The latest signed device host is prepared but not installed: /Users/tip/games/scratch/cyberpunk-staged-startup/DerivedData/Build/Products/Debug-xros/CyberpunkStartupFileProbe.app . Next time, normally update bundle local.games.cyberpunk.assetreceiver and launch on an awake headset. Preserve its verified 147.58 GiB data container; do not uninstall or retransfer assets. Original-engine testing of the latest policy/input changes remains pending.

Evidence: /Users/tip/games/cyberpunk-avp/research/window-init-adapter-validation-2026-10-12.json . Simulator result: /Users/tip/games/scratch/cyberpunk-window-init-simulator/results.json . Repeated build targets: make -C /Users/tip/games/scratch/cyberpunk-staged-startup host or simulator. Direct-close delegate behavior follows Apple's documentation: https://developer.apple.com/documentation/appkit/nswindow/close%28%29 .

## Staged-asset startup test — October 12, 2026

The small original-engine host was installed as a normal update using the receiver bundle identifier, preserving all staged assets. A narrow filesystem adapter maps bundle Data paths to real Application Support/GameData/Data paths and leaves native errors intact. Mac controls passed exact reads, stat/access/directory queries, missing paths, prefix boundaries and invalid pointers. On the physical M2 headset, the engine loaded its dependency graph and opened 77 distinct original archives plus script and Metal shader caches, passing the previous missing-base-archives assertion.

Startup first aborted on AGXG14GDevice.isDepth24Stencil8PixelFormatSupported, a macOS-only Metal query. Xcode27 MTLDevice.h explicitly says the format was never supported on Apple Silicon. A process-local adapter now supplies the truthful false response only when that method is absent. Physical retesting confirmed the adapter and successful creation of a native Depth32Float/Stencil8 texture. Startup progressed past that query, then aborted on another unsupported Objective-C method. The next callsite resolves statically to the HDR display query maximumPotentialExtendedDynamicRangeColorComponentValue; the crash report itself redacts the method name. Native HDR/EDR display capability adaptation is the next step. No game frame or VR gameplay has been shown.

Evidence: /Users/tip/games/cyberpunk-avp/research/staged-asset-startup-test-2026-10-12.json . Host, traces and both matching crash reports: /Users/tip/games/scratch/cyberpunk-staged-startup/ . The verified source bundle remains unchanged. Do not uninstall the current app or recopy the assets.

## Original asset transfer complete — October 12, 2026

The remaining background batch finished sending at 1:05 AM Eastern. All 418 jobs have native accepted receipts, with zero rejections. The headset's persisted checkpoints confirm all 110 original game-data files are whole-file SHA-256 verified, with exact original byte counts and manifest hashes: 158,461,863,365 bytes (147.58 GiB). This is native verification, not a second full dataset readback to the Mac. Diagnostic fixtures are excluded from that total.

The local batch server has been stopped; its scoped idle-sleep prevention exits with it. Preserve the receiver app and its data container. Next is connecting the original engine's asset-root lookup to Application Support/GameData and testing startup. No first game frame, gameplay or VR has been demonstrated.

Evidence: /Users/tip/games/cyberpunk-avp/research/background-asset-transfer-complete-2026-10-12.json . Raw native receipts and checkpoints: /Users/tip/games/scratch/cyberpunk-background-asset/completion-receipts/ and completion-checkpoints/ . Older progress figures below are historical.

## Real game archive background transfer — October 11, 2026

Two 64 MiB chunks of the original English voice archive advanced its actual native checkpoint from 2,952,790,016 to 3,087,007,744 bytes (2.875 GiB), adding 128 MiB to the game transfer. The first download completed off-head but its commit waited for unlocking. We corrected the background callback ordering so the serial checkpoint processing completes before signaling completion to visionOS. The second chunk downloaded, passed SHA-256 checks and was acknowledged at the new offset while the headset was off, before any request to re-wear it.

A batch scheduler is now built, installed and configured with 418 remaining chunks totaling 84.33 GiB. It schedules the jobs together, retains completed downloads that arrive out of order, and commits only from each asset's saved verified offset. Original full-file SHA-256 remains required at archive completion. Its private local server serves allowlisted original ranges directly from the preserved Mac source, with bearer authentication and Range/ETag retry support. Six new range-planning tests, existing recovery/corruption tests, signed builds, and actual server byte/auth/range checks pass. The batch started after the final unlock. Native receipts confirmed six 256 MiB English chunks plus the Spanish text archive, bringing the English checkpoint to 4,697,620,480 bytes. After the user removed the headset, queued downloads continued at the server; further native batch checkpoint advances after that removal have not yet been confirmed. Full-batch completion remains pending. Server byte counts are not verified device-byte counts. No first game frame or VR gameplay is demonstrated.

Evidence: /Users/tip/games/cyberpunk-avp/research/offhead-real-archive-transfer-2026-10-11.json . Native checkpoint files and per-test receipts are under /Users/tip/games/scratch/cyberpunk-background-asset/ . The plan contains a private bearer token and must not be printed or shared. Do not run the old developer-copy writer concurrently or uninstall the receiver. Leave the Mac running on the same network; its idle-sleep prevention is scoped to the batch-server process. OS background scheduling still controls timing, so uninterrupted completion is not guaranteed.

## Off-head background download probe — October 11, 2026

A separate public background URLSession probe downloaded a synthetic 2 MiB file on M2 Vision Pro. The user confirmed removal at 02:44:37 UTC (October 11, 10:44 PM Eastern). The native receiver recorded complete_hash_verified at 02:47:30 UTC, and the retrieved file independently matched the original SHA-256 on the Mac. The user confirmed that the headset remained off continuously until unlocking after completion; the synthetic off-head download is physically confirmed. This is evidence for background asset delivery, not for keeping the game or debugger active off-head. The private synthetic server was stopped after verification.

Real archive-scale background delivery and integration with existing verified checkpoints remain pending. The previous developer-copy transfer is not currently running; its last durable progress is 63.12 GiB of 147.58 GiB (42.8%), with retained checkpoints. Do not uninstall the receiver. No first game frame or VR gameplay has been demonstrated.

Apple explicitly says no supported off-head caffeination mode exists: https://developer.apple.com/videos/play/wwdc2026/8004/?time=2267 . Background downloads use the supported alternative documented at https://developer.apple.com/documentation/foundation/downloading-files-in-the-background . Evidence: /Users/tip/games/cyberpunk-avp/research/offhead-background-download-2026-10-11.json .

<!-- native-memory-assets-20261011 -->

## Receiver memory correction and recovery — October 11, 2026

The receiver stopped while verifying the large soundbanks archive. Its persisted checkpoint retained 8 GiB across 32 verified chunks. Investigation found a reproducible buffering bug in our Swift receiver: Foundation read buffers remained autoreleased until the entire hash operation ended. A two-GiB Mac scan reached 2,163,834,880 resident bytes; per-buffer cleanup reduced the same scan to 10,960,896 bytes. All recovery/corruption tests pass, and a permanent memory regression test requires a two-GiB scan to stay below 128 MiB. These are host memory measurements, not game or headset frame-performance metrics.

After a normal receiver update preserving its data, the already-delivered pending packet completed without reupload. The headset verified the original full SHA256 of audio_2_soundbanks.archive (8,828,301,312 bytes). The resumed host skipped both completed audio archives and advanced into basegame_1_engine.archive. The exact OS termination reason was not captured; the disk-write reports said no action was taken. The memory defect is reproduced and fixed, and the formerly stopped large-file stage now completes.

Evidence: /Users/tip/games/cyberpunk-avp/research/resumable-memory-recovery-2026-10-11.json . Current transfer is checkpointed; a device disconnection can still pause it without losing verified offsets. Native game-host path integration, completion of the full dataset, a first game frame and VR remain pending.

## Resumable asset delivery — October 11, 2026

The large all-in-one installation was replaced with a small signed native receiver and checkpointed file transfers. Its physical M2 test saved 1 MiB, restarted the receiver process, sent only the remaining 1 MiB, and verified the complete original SHA256. The file retrieved back to the Mac matched the original. A normal app update retained that verified file. Seven host corruption/path/recovery checks also pass. These tests establish the receiver's continuation mechanism, not full-game startup or performance.

The 110 original game-data files are now transferring in packets of up to 256 MiB. Each written chunk is hash checked before a synchronized output and atomic checkpoint are acknowledged; a complete file requires the original SHA256. The first real archive, 198,008,832 bytes, completed verification, and the next archive is advancing. Native space checks protect writes. A failed attempt can be continued with `make -C /Users/tip/games/cyberpunk-avp/resumable resume`; completed original files and verified offsets are rechecked rather than retransferred. The current receiver uses Apple's developer file-copy transport rather than an HTTP server.

Keep the receiver window open while transferring. Taking the headset off locks it and puts it to sleep, per Apple's guide: https://support.apple.com/guide/apple-vision-pro/wake-and-unlock-tan3ab1ebc01/visionos . Processing or the connection may stop; saved verified chunks remain, and the current unfinished packet may need to be resent. The separate background URLSession probe below now has physical evidence for a synthetic off-head download; the original developer-copy archive transport has not been converted to it. Actual app restart and app-update retention were also tested.

The receiver stores data in its persistent Application Support/GameData directory. Future game-host updates must preserve bundle identifier `local.games.cyberpunk.assetreceiver` and its data container. Do not uninstall it as a retry strategy. The original engine still needs a real asset-path compatibility layer for this container location. Original game code is not yet part of the receiver, and no first game frame or VR play has been verified. The previous full signed app and immutable source remain preserved.

Implementation: /Users/tip/games/cyberpunk-avp/resumable/ . Evidence: /Users/tip/games/cyberpunk-avp/research/resumable-receiver-physical-results.json . Live local progress: /Users/tip/games/scratch/cyberpunk-resumable/transfer/progress.json .

## Native startup update — October 11, 2026

The physical M2 Vision Pro passed the disclosed 16/8/8 GiB capacity experiment: all three original 4 GiB world-pool reservations succeeded, all original initializers completed, and original main returned 0. This is startup evidence, not a game frame. A subsequent bootstrap run opened real configuration, settings and tweakdb files, then hit the original missing-base-archives assertion. No observed native allocation failure caused that bootstrap crash.

All 110 original game-data files (158,461,863,365 bytes) are now staged and hash verified. Only the archive platform directory spelling changes from `Mac` to `mac`, matching the engine's actual lookup. Normal signing is complete, both supported memory entitlements are present, and all original Data hashes match the signed resource seal. Executable/framework signature checks passed; resource bytes were independently hash checked rather than scanned a second time by codesign.

Full installation is still unconfirmed. The first command was stopped after Mac free space fell to 266 MB. Free space subsequently recovered, and the obsolete incomplete-download scratch backup was removed; the complete verified image and signed app remain intact. Sampling then showed Apple's shared CoreDevice service continued streaming the original installation even after its command exited. A queued retry was stopped to avoid a duplicate. Device connectivity is currently reported connected, but an installed-app query timed out. Do not launch or claim full installation until actual device state confirms it. No first game frame, gameplay, stereo rendering or VR interaction has been demonstrated.

Evidence lives under `/Users/tip/games/cyberpunk-avp/research/`, including `native-startup-capacity-result-2026-10-11.md`, `device-bootstrap-assets-crash-analysis.json`, `complete-game-data-stage-results.json` and `complete-game-data-resource-seal-verification.json`. Transfer samples and receipts are under `/Users/tip/games/scratch/cyberpunk-full-assets/`.
## Latest native startup evidence

The original engine reached startup on M2 Vision Pro. A native pass-through mmap/madvise trace now proves the specific failure: after62GiB of recorded large successful reservations, a4GiB world-pool reservation returned MAP_FAILED/ENOMEM12. This is not proof of an exact global limit. The separate16/8/8GiB initial-capacity experiment retains the original4/4/4GiB world pools; native Mac initializer control, physical build/signature/install passed. Its physical launch remains unconfirmed while the headset is off for bedtime.

Mac-side original asset resolver tests succeeded. Running the host from bin produced bin/Data/; running it from MacOS produced the parent's Data/. For the flat visionOS bundle, Data beside the executable is the candidate layout. Actual device resolver/file-open behavior remains to verify. Original Data/Resources inventory is112files totaling147.582GiB; no game assets have been staged. No first game frame, gameplay, or VR is confirmed.

Detailed local evidence: /Users/tip/games/cyberpunk-avp/research/native-original-entrypoint-2026-10-11.md and native-asset-path-audit-2026-10-11.md, plus native memory trace and both Mac resolver reports.

<!-- native-original-entrypoint-20261011 -->
The original Cyberpunk entrypoint now EXECUTED on physical M2 Vision Pro and reached engine startup. Separate startup probe run943CE1E0-242D-44F0-9CF3-3AB84A917D04/PID2013 uses the disclosed16/16/16GiB capacity experiment, all6538 initializer entries and the real original main. Its native crash stack confirms main100034ad8 and engine-root100034b2c; the pre-call checkpoint alone would not prove this. It stops at original failure reporter10002733c through a world-pool commit failure path while constructing the third of three4GiB pools. The actual failed reservation address and syscall errno remain uncaptured. No game assets are staged yet, no game frame/gameplay/VR exists. Next: genuine native reserve/commit instrumentation before further tuning. Full evidence: /Users/tip/games/cyberpunk-avp/research/native-original-entrypoint-2026-10-11.md.
<!-- /native-original-entrypoint-20261011 -->

<!-- native-initializers-complete-20261011 -->
Native investigation resumed and the earlier stopping conclusion was premature. A separate normally signed experiment changes only two hard-coded pool-capacity instructions:16/64/32GiB becomes16/16/16GiB, with all6538 initializer entries retained, all other text bytes and28 other sections unchanged. Native mmap/advice and allocator logic remain real; no larger mapping request is falsely satisfied by a smaller block. Independent post-sign section comparison passes.

Physical M2 Vision Pro run9CCFFB0B-146B-41F1-9BC3-C1DD01C9DB3A (PID2010) now successfully completes dlopen and the original initializer graph: GAME_GRAPH_LOAD_SUCCEEDED_NO_ENTRYPOINT. Native Mac control run1DF24FD2-8426-4ADE-A811-21175D4EF9CA also succeeds. The initializer blocker is cleared for this experimental configuration. Original entrypoint, first game frame, gameplay-capacity correctness and VR remain untested. Next: actual startup and asset loading. Evidence: /Users/tip/games/cyberpunk-avp/research/native-pool-capacity-experiment-2026-10-11.md.

Reusable work for other games: selected UIKit-backed desktop/window/display/pointer API adapters, native dependency probes and loader diagnostics. This is scoped compatibility coverage, not full AppKit emulation; game-specific engines, assets, middleware rights and VR/rendering still need separate work.
<!-- /native-initializers-complete-20261011 -->

<!-- native-investigation-stop-20261011 -->
Investigation stopping point: the unchanged original allocator hard-codes simultaneous16/64/32GiB virtual reservations. Supported Extended Virtual Addressing fixes the first failure, but physical M2 controls cannot hold all three; changing order and testing ordinary4GiB/64GiB address hints do not fix it. The low-memory branch reduces preallocation, not reservation sizes. Further work needs substantive engine memory-policy changes and allocator/gameplay validation. Native Cyberpunk port, original game frame and VR are still incomplete. Exact original mmap errno was not directly captured; original invalid range and separate native ENOMEM controls were captured. Full audit and evidence: /Users/tip/games/cyberpunk-avp/research/native-port-investigation-stop-2026-10-11.md.
<!-- /native-investigation-stop-20261011 -->

<!-- reservation-capacity-update-20261011 -->
The physical M2 Vision Pro now has a reproducible simultaneous virtual-reservation failure despite Extended Virtual Addressing. A separate native control holds 16, 64, and 32 GiB requests: 16 succeeds, 64 fails ENOMEM12, 32 succeeds. Moving 64 first makes both later requests fail. The identical Mac control succeeds in both orders. Individual 64 GiB reservations succeed on both systems; these tests touch only one byte per successful mapping and do not measure physical RAM capacity or establish an exact address-space ceiling.

The original game debugger captured madvise failing on address MAP_FAILED (-1), length704MiB, advice8, errno22. Its medium-pool configuration requests64GiB and stores the failed reservation sentinel, then continues initialization; this precedes the later64-byte PoolDebug allocation failure. Capturing the original mmap errno remains pending. Native advice7/8 controls pass on both platforms, so an advice replacement is not justified. A native Mac original graph control completes every original initializer and exits0; no original entrypoint is called.

Next work is a validated engine memory configuration or allocator redesign that reduces simultaneously reserved ranges while retaining real allocation semantics. Dependency resolution alone cannot clear this reproduced failure. No original game frame/gameplay/VR exists. The observed circle and trackpad interaction confirm a visible window only. Full evidence: /Users/tip/games/cyberpunk-avp/research/native-extended-virtual-addressing-2026-10-11.md; physical sequence run16FBDEB3-3A53-41CB-BC3D-ED6B0141364C.
<!-- /reservation-capacity-update-20261011 -->

<!-- extended-va-update-20261011 -->
Physical M2 Vision Pro now passes the first original allocator crash with Apple’s supported Extended Virtual Addressing capability. Controlled native16GiB mmap: default fails ENOMEM12; extended capability succeeds, writes/reads one byte, and unmaps successfully. This is a virtual reservation test, not16GiB of physical RAM. Original gamehost signature and Apple provisioning profile authorize the capability; all29 original file-backed sections and initializer entries remain intact. Original graphrun9FF6A567-199C-4246-BD8A-F4944F36C189 reaches a later initializer, then crashes while reporting a failed64byte PoolDebug allocation. No successful initializer completion, main entrypoint, game frame or VR yet. Evidence: /Users/tip/games/cyberpunk-avp/research/native-extended-virtual-addressing-2026-10-11.md.
<!-- /extended-va-update-20261011 -->

<!-- initializer-crash-update-20261011 -->
The original Cyberpunk module now reaches an original initializer on M2 Vision Pro, then crashes in allocator initialization. Matching device crash evidence shows an unchecked null-pointer write at original address0x1000084d8, called from initializer0x10003a1b4. The earlier cause is unresolved; static code includes a16GiB range request, but this does not prove a memory entitlement or address-space restriction. All24 directly imported AppKit symbols and the CoreGraphics display-mode option now resolve; five mode-option checks passed physical and simulator. Original initializer completion, main entrypoint, game frames and VR remain unproven. Initializers remain intact. Evidence: /Users/tip/games/cyberpunk-avp/research/native-display-mode-option-initializer-crash-2026-10-11.md. Next: actual allocator runtime state and original Mac comparison.
<!-- /initializer-crash-update-20261011 -->

<!-- workspace-url-update-20261011 -->
All 24 directly imported AppKit symbols now resolve in the physical original Cyberpunk dependency probe. Its next confirmed gate is kCGDisplayShowDuplicateLowResolutionModes. Native NSWorkspace URL handoff passed 14 checks on M2 Vision Pro and simulator, including actual own-app URL success/delivery and unhandled-URL failures. The synchronous BOOL returns NO while the native result is pending; the inspected original caller discards it. Browser/game URL behavior and complete AppKit compatibility remain unproven. Evidence: /Users/tip/games/cyberpunk-avp/research/native-workspace-url-physical-load-2026-10-11.md. No original initializer completion, entrypoint, game frame or VR yet.
<!-- /workspace-url-update-20261011 -->

<!-- tracking-area-update-20261011 -->
The native tracking-area bridge passed 15 checks on physical M2 Vision Pro and simulator. The original dependency probe now stops at NSWorkspace; 23/24 imported AppKit symbols are present. A real native hover recognizer is attached, but fixture events were synthetic and no physical pointer samples were observed. Original initializer completion, game entrypoint, frame, gameplay and VR remain unproven. Full evidence: /Users/tip/games/cyberpunk-avp/research/native-tracking-area-physical-load-2026-10-11.md.

Intended input: PS VR2 Sense left/right controllers for gameplay (assuming PS2 VR means PS VR2), headset pose for camera, and gaze/pinch for menus. Pairing and tracked controller gameplay have not been tested. Apple pairing guidance: https://support.apple.com/guide/apple-vision-pro/connect-spatial-accessories-tan7a3f2c9d3/visionos .
<!-- /tracking-area-update-20261011 -->

<!-- desktop-menu-tracking-gate-progress -->
The original game dependency probe now reaches NSTrackingArea on M2 Vision Pro (476B4961-20D6-4F9B-8A69-41FAE0E3BB40);22/24 imported AppKit symbols resolve. NSMenu visibility requests concern macOS's absent system menu bar and are explicitly reported unsupported, with actual visibility/capability false. This does not implement in-game menus. Remaining tracking-area behavior needs genuine key-window-gated enter/exit events and responder dispatch;0x21 means entered/exited plus active-in-key-window. NSWorkspace URL handoff also remains. No original game frame exists. Evidence: /Users/tip/games/cyberpunk-avp/research/remaining-appkit-desktop-menu-boundary-2026-10-11.md.
<!-- /desktop-menu-tracking-gate-progress -->

<!-- intended-sense-controller-input -->
Intended gameplay hardware: PS VR2 Sense controllers paired to Vision Pro (interpreting the user’s “PS2 VR” reference as PS VR2). Apple supports these spatial controllers from visionOS26, with buttons through Game Controller and spatial pose tracking. Each controller pairs separately. Intended menus use gaze targeting and pinch, with head tracking for the camera; controller selection and stick locomotion are proposed additions. The game needs a native bridge from controller poses/buttons to gameplay and weapon interactions; this is not yet implemented or physically tested. Sources: https://developer.apple.com/videos/play/wwdc2025/289/ and https://support.apple.com/guide/apple-vision-pro/connect-spatial-accessories-tan7a3f2c9d3/visionos.
<!-- /intended-sense-controller-input -->

<!-- native-cursor-gaze-progress -->
Native image/cursor adapters pass fourteen cursor checks on M2 Vision Pro and simulator. The original game dependency graph advances to NSMenu (A86DB2F8-66B1-4B4B-A4D9-873C726B173D);21/24 imported AppKit symbols now resolve. Actual trackpad movement/visibility is not yet verified. Eyes and pinch are the intended primary menu interaction; Apple offers privacy-preserving immersive Metal hover targets but does not expose continuous raw gaze coordinates. Game UI target/input integration remains future work. No original game frame exists. Evidence: /Users/tip/games/cyberpunk-avp/research/native-cursor-regions-physical-load-2026-10-11.md.
<!-- /native-cursor-gaze-progress -->

<!-- native-bitmap-image-progress -->
The NSImage bitmap adapter passes eight real pixel/context checks on M2 Vision Pro and the visionOS simulator: transparent cursor image construction, opaque source copying, empty-source preservation, backing scale, nested focus restoration, half-opacity alpha, focus ordering and native ABI. It is compiled into the shared host but not yet staged into the original game graph. Cursor regions and window invalidation are next; no original game frame exists. Evidence: /Users/tip/games/cyberpunk-avp/research/native-image-contracts-2026-10-11.md.
<!-- /native-bitmap-image-progress -->

<!-- cursor-image-contract-progress -->
Cursor audit confirms that the game constructs its hidden cursor from an empty8x8 image and relies on current-cursor identity, cursor rectangles and invalidation. Native Mac reference pixels are fully transparent. UIKit has a genuine region-specific hidden pointer style; implementing image drawing and view-owned regions is next. No cursor adapter or physical pointer visibility is yet verified. See /Users/tip/games/cyberpunk-avp/research/cursor-image-contract-audit-2026-10-11.md.
<!-- /cursor-image-contract-progress -->

<!-- appkit-notification-game-progress -->
Physical M2 Vision Pro notification checks pass, and the original game dependency load now advances to missing NSCursor (run 4E5E3D2A-1CEF-4F51-A51D-682A90E765D4). Six AppKit global values match native Mac queries; 19 of 24 directly imported AppKit symbols are present. Scene snapshot and key-state notification ordering are verified in the own probe, with resize and activation test limits documented. The original game has not completed loading or produced a frame. Evidence: /Users/tip/games/cyberpunk-avp/research/appkit-notification-contracts-physical-load-2026-10-11.md.
<!-- /appkit-notification-game-progress -->

<!-- native-metal-observer-game-progress -->
Native Metal enumeration and observer ownership now pass seven checks on physical M2/simulator, both exposing the actual single GPU. The adapter uses native MTLCopyAllDevices, preserves the documented registry/caller retains and emits no artificial device-change events. A distinct Metal forwarding provider is staged in the original graph. Physical72E4D67A-74C0-4C4E-8C4A-E6431C79E98D advances to NSApplicationDidChangeScreenParametersNotification, superseding Metal enumeration as the first observed loader gate. No original graph initializer completion, entrypoint or frame yet. Evidence: /Users/tip/games/cyberpunk-avp/research/metal-observer-contracts-physical-load-2026-10-11.md.
<!-- /native-metal-observer-game-progress -->

<!-- iokit-monitor-game-progress -->
Monitor adapters now preserve the observed Mac absent-service dictionary (IODisplayLocation=unknown) and float failure with unchanged default value. Five bounded checks pass on M2/simulator; valid physical metadata and full desktop options remain unverified. The original graph maps through a distinct IOKit forwarding framework. Physical953C3781-BBA5-4BD2-8A14-CEDABFB6C036 advances to MTLCopyAllDevicesWithObserver in native Metal, superseding the monitor-info symbol as the first observed gate. No original graph initializer completion, game entrypoint or frame yet. Evidence: /Users/tip/games/cyberpunk-avp/research/iokit-display-contracts-physical-load-2026-10-11.md.
<!-- /iokit-monitor-game-progress -->

<!-- desktop-pointer-contracts-game-progress -->
Four desktop pointer/display contracts are now staged in the verified original game graph: nullable event-source failure, guarded suppression boundary, registered scene main display ID and explicit unavailable cursor warp. Seven grouped fixture checks pass on M2 and simulator. Physical original graph680ED1A0-E632-4922-96C0-21DEACA58877 now stops at IODisplayCreateInfoDictionary in native IOKit, superseding CGEventSourceCreate as the first observed gate. This does not prove complete CoreGraphics/AppKit behavior or game execution. Evidence: /Users/tip/games/cyberpunk-avp/research/desktop-pointer-contracts-physical-load-2026-10-11.md. No game frame yet.
<!-- /desktop-pointer-contracts-game-progress -->

<!-- game-pointer-adapter-progress -->
The tested cursor association adapter is now staged in the original game graph, with its real host controller and native scene snapshot registered. Physical09EE910F-DB4F-4E39-A003-74218A3A50A3 passes that symbol and stops at CGEventSourceCreate. This supersedes cursor association as the first observed loader gate. Original graph initializer completion, game entrypoint and game frames remain unproven. Evidence: /Users/tip/games/cyberpunk-avp/research/game-pointer-adapter-physical-load-2026-10-11.md.
<!-- /game-pointer-adapter-progress -->

<!-- native-pointer-contract-progress -->
Cursor association adapter now uses native UIKit preference and actual scene lock state. Physical CD46E3C6-1F5F-485F-9434-300EFF1FD41A reports zero connected mice, nil pointer-lock state and explicit not-implemented errors; six absent-backend checks pass. Successful pointer locking and relative input remain unverified. The adapter has not yet been staged in the original game graph, whose latest first gate remains CGAssociateMouseAndMouseCursorPosition. Evidence: /Users/tip/games/cyberpunk-avp/research/native-pointer-contract-2026-10-11.md. No game frame yet.
<!-- /native-pointer-contract-progress -->

<!-- consolidated-host-game-graph-progress -->
The consolidated own host adapters are now mapped into a separate, payload-verified game copy on M2 Vision Pro. A distinct display forwarding framework resolves duplicate dependency identities. Corrected physical run3DC24DA5-DCB0-48B6-95CF-3672059D7C40 reaches symbol resolution and stops at CGAssociateMouseAndMouseCursorPosition, superseding the missing AppKit image as the first observed loader gate. AppKit coverage remains13/24 required exports; additional desktop APIs and behaviors remain unresolved. No original graph initializer completion, game entrypoint, game frame or VR yet. Evidence: /Users/tip/games/cyberpunk-avp/research/game-host-physical-load-2026-10-11.md.
<!-- /consolidated-host-game-graph-progress -->

<!-- native-first-responder-progress -->
Native first responder handling and explicit content-view window ownership passed eight checks on physical M2 Vision Pro and simulator. Physical run E96F6142-8C41-4265-85ED-BB290BA0358C. The existing display aliases and own Metal draw remained passing. Keyboard/pointer translation, tracking areas, fullscreen/style transitions and original AppKit graph integration remain open. No original game frame yet. Evidence: /Users/tip/games/cyberpunk-avp/research/native-first-responder-2026-10-11.md.
<!-- /native-first-responder-progress -->

<!-- native-display-abi-progress -->
All20 desktop display API aliases passed in the own normally signed fixture on physical M2 Vision Pro and simulator. Physical run: C7A1AE07-BFD0-4831-8048-8E83F2891EBA. Enumeration, dimensions, mode lifetime, virtual viewport classification and unavailable hardware metadata checks passed; the fixture completed its native Metal draw. This does not demonstrate original game execution. AppKit remains the main loader gate; selector coverage, native input and integration remain open. Evidence: /Users/tip/games/cyberpunk-avp/research/native-display-abi-2026-10-11.md.
<!-- /native-display-abi-progress -->

<!-- native-refresh-precision-progress -->
Refresh precision is resolved in the port adapter: explicit0.001Hz near-integer normalization yields nominal90 while retaining raw89.9998875. Actual M2 run4A052C84-1AC4-4341-B4A3-73C54A5E926F and simulator pass;59.94/23.976 remain fractional in tests. RealMac unavailable-display queries revealed UINTMAX vendor/model/serial and-1 builtin/mirroring sentinels, so remaining hardware contracts must distinguish valid scene semantics from unknown hardware. No original display binding or game frame; AppKit remains the loader gate. Evidence: /Users/tip/games/cyberpunk-avp/research/native-refresh-precision-2026-10-11.md.
<!-- /native-refresh-precision-progress -->

<!-- native-display-mode-progress -->
Retained scene mode snapshots/arrays now pass on physical M2 Vision Pro (run2C10DB46-DBDA-4174-8D22-B4CB7A31F09F) and simulator, including array-release/unregister lifetime and immutable snapshots. Actual native display-link period yields89.9998875Hz; this is scheduling observation, not gameFPS. Original integer truncation would report89, so refresh precision remains before original binding. Hardware metadata/IOKit and remaining AppKit interfaces are still open. No game entrypoint/frame/VR. Evidence: /Users/tip/games/cyberpunk-avp/research/native-display-mode-2026-10-11.md.
<!-- /native-display-mode-progress -->

<!-- native-display-query-progress -->
Thread-safe registered scene display queries now pass on M2 Vision Pro (run9576E024-450E-4BD2-A23F-A1AE86E680CE) and simulator, including a real background thread. Actual1280x720 logical geometry and scale2 produce2560x1440 backing query dimensions; the test render remains1280x720. Twenty original display imports/36direct calls are audited. Retained mode objects, native flags, refresh and hardware-query semantics remain before original bindings. AppKit remains the main loader gate; no Cyberpunk game frame or VR. Evidence: /Users/tip/games/cyberpunk-avp/research/native-display-query-2026-10-11.md.
<!-- /native-display-query-progress -->

<!-- native-screen-scene-progress -->
The registered scene viewport adapter now passes on physical M2 Vision Pro (run3E0E6249-A5DE-45E4-B38C-D812A37135AE) and simulator: actual1280x720 logical bounds, safe area, backing scale2, stable scene registration and removal. Native host Metal clear still completes. The screen number is port-local, not a desktop CGDisplayID; CoreGraphics display/mode calls must be adapted consistently before game use. Main AppKit remains unresolved and there is no native Cyberpunk frame/gameplay/VR. Evidence: /Users/tip/games/cyberpunk-avp/research/native-screen-scene-2026-10-11.md.
<!-- /native-screen-scene-progress -->

<!-- native-window-scene-progress -->
The own window/view host now runs inside a real scene on M2 Vision Pro (run950CC8E1-91A0-43B9-B09E-46FB91CE65BF) and the simulator. Logical guest key-window mapping and native activation agree; a1280x720 Metal clear completes through the attached guest layer. This is host rendering, not a Cyberpunk frame. Screen/monitor geometry, input, styles and remaining original selectors still need work before resolving the main AppKit dependency. No full game graph, entrypoint, gameplay or VR is proven. Evidence: /Users/tip/games/cyberpunk-avp/research/native-window-scene-2026-10-11.md.
<!-- /native-window-scene-progress -->

<!-- combined-galaxy-physical-progress -->
The combined main-game loader with real Curl/Bink and physically verified AppStore/Galaxy dependencies now reaches the missing AppKit framework on M2 Vision Pro (run70DC3AB8-7634-45E6-BC4D-71D198517930). Galaxy separately loads on the physical headset (run804FBE2D-B28C-44C5-8DCF-316ED822A207). Main29sections and all import records are preserved. Next is the24strong AppKit imports and their real window/view/event/screen behavior, including guest subclass layouts. No full graph initialization, game entrypoint, frame, gameplay or VR yet.
<!-- /combined-galaxy-physical-progress -->

<!-- galaxy-simulator-progress -->
Galaxy's original adapted copy loaded on the actual visionOS simulator (run 5B2F2052-AD08-4A82-8D7B-23DA19D98BFA). Four genuine native Security adapters are linked; all15 file-backed sections and original code/initializers remain unchanged, with667 chained imports and519187 nlist records verified. The probe calls no exported services or game entrypoint. Physical Galaxy testing and the combined game graph remain next; there is no headset gameplay or VR yet. See local research/galaxy-simulator-load-2026-10-11.md for measured limits.
<!-- /galaxy-simulator-progress -->

# Cyberpunk 2077 Mac → Apple Vision Pro: research and feasibility specification

<!-- galaxy-spki-progress -->
Galaxy TLS adaptation progressed: an own native public-key encoder matches real desktop Security SPKI bytes for six RSA/EC cases and passes20 checks on Mac and20 in the visionOS simulator. It preserves the bytes needed by original pinning rather than returning incompatible raw native keys. Device compilation passes, but physical execution, client identity import/lookup, certificate-description fixtures and Galaxy loading remain pending. No original game code or TLS trust/pinning behavior was changed. See [component evidence](/Users/tip/games/cyberpunk-avp/research/native-security-key-export-fixture-results.json).

<!-- appstore-physical-progress -->
The adapted original App Store dependency now loads on the physical M2 Vision Pro (run5EE776A5-8946-42BA-A62F-7C2B019C8071). The combined main loader with real Curl/Bink/AppStore advances to missing libREDGalaxy64.dylib (runF51DECBA-74FA-49DD-9B81-3E05D257CD73). Original main29sections and AppStore24sections are preserved, and five AppStore imports use genuine native host adapters. No game entrypoint, frame, gameplay or VR is proven. Galaxy's next audited boundary is four desktop Security APIs in its embedded TLS code. See [physical dependency results](/Users/tip/games/cyberpunk-avp/research/game-appstore-physical-load-2026-10-11.md).

<!-- appstore-simulator-progress -->
The adapted original App Store dependency now loads in the visionOS simulator (run4C8A2EF8-24DD-4D62-8137-5D3AE7FE50D0). Five reviewed imports use genuine lifecycle, UIKit presentation and native logging adapters; all24 original sections and exports are preserved. Own adapters passed33 simulator checks, and the event component passed25. No exported service function, authentication request or game entrypoint was called. Physical device and combined game loads remain pending. See [dependency load evidence](/Users/tip/games/cyberpunk-avp/research/appstore-simulator-load-2026-10-11.md).

<!-- native-bink-physical-progress -->
Physical M2 continuation: Bink loaded successfully (run848C0DBC-5BC8-4D52-A3CB-AB7BAE975837); the previously timed-out launch completed later and was observed without retry. The actual game copy with real Curl and Bink now reaches a missing original GameServicesAppStore library (runF03D7B43-9382-41EB-8587-5023C1C5C755). No Bink API or game entrypoint was called. Original sections and logical providers were verified. Separately, the UIView/Metal-layer host connector passes11 simulator checks; drawable rendering and physical input remain untested. See [physical dependency results](/Users/tip/games/cyberpunk-avp/research/native-bink-and-game-physical-load-2026-10-11.md).

<!-- simulator-native-progress -->
Simulator testing completed: our event component passes 21 checks in the visionOS 27 Foundation runtime; real source-built simulator curl passes custom-allocator initialization and local-file easy/multi transfers through all 16 required APIs; the audited Bink copy loads. The actual game copy with real Curl and Bink stops at MetalFX, which is missing from this simulator runtime/SDK. No game entrypoint, Bink decoding/audio, game frame or VR was executed. This simulator limitation does not establish a physical-device blocker. See [simulator results](/Users/tip/games/cyberpunk-avp/research/simulator-continuation-2026-10-10.md).

<!-- native-deps-device-progress -->
Latest dependency gate: the physical M2 game-copy loader now reaches the missing Bink library after verified native framework path changes and controlled removal of the unused main Cocoa umbrella. All 29 original file-backed sections remain identical; binding ordinals were remapped with logical providers preserved. This is a dependency-loading result, not engine execution. See [measured loader result](/Users/tip/games/cyberpunk-avp/research/game-native-deps-load-2026-10-10.md). A separate own application/event component compiles for visionOS and passes 21 Mac-host behavior checks; physical input and game integration remain untested. A separate Bink copy now passes the symbol-string alignment check and reaches a missing macOS AudioUnit path; no Bink APIs were called. See [Bink results](/Users/tip/games/cyberpunk-avp/research/native-bink-load-2026-10-10.md). AudioUnit/Carbon contribution auditing is next.

<!-- native-curl-device-progress -->
Native curl update: a real visionOS curl framework passed physical-M2 loading, all 16 required symbol lookups, global initialization and easy-handle creation/cleanup without network access. A separate game copy with only its curl path adapted now fails at the Mac MetricKit framework path. Original game section bytes and curl version requirements remain unchanged. This advances dependency loading, not engine initialization/gameplay. See [real curl and game-loader results](/Users/tip/games/cyberpunk-avp/research/game-native-curl-load-2026-10-10.md), [actual call surface](/Users/tip/games/cyberpunk-avp/research/native-curl-call-surface-2026-10-10.md), and [all 24 dependencies](/Users/tip/games/cyberpunk-avp/research/dependency-matrix.csv). The MetricKit native-path test also completed: the actual loader now fails at the absent Cocoa.framework Mac path. See [the latest measured boundary](/Users/tip/games/cyberpunk-avp/research/game-native-curl-metrickit-load-2026-10-10.md). Cocoa/AppKit host adaptation is the next work; native engine/gameplay/VR gates remain open.

**Current direction — October 10, 2026:** Continue native dependency/platform adaptation at the user's explicit request. The proposed stopping decision below is superseded. First build real visionOS libcurl against the game's imports, then advance the actual loader/host toward a native mono game frame. All 20,024 cache library records loaded, and normally provisioned increased-memory support yielded ~7.98 GiB remaining probe headroom. No game entrypoint, game frame, gameplay or VR has run on Vision Pro; those original gates remain open. See the [host boundary and gate audit](/Users/tip/games/cyberpunk-avp/research/native-port-decision-2026-10-10.md). Earlier entries are historical where superseded.

## Visible native calibration — October 10, 2026

A standard native MTKView ran on the M2 Vision Pro. The user confirmed red followed by green with the window still open. All 120 GPU completions, exact pixel checks and presentation callbacks passed; GPU timestamps were valid. The scene was foreground active at the recorded samples, and rendering required an active scene and attached visible view. All drawable presentedTime values remained zero. The strict timing criterion remains failed, but this control shows it cannot reliably establish visibility in our tested setup. This does not prove a general platform limitation or a specific root cause.

The engine consumer follow-up identified adjacent acknowledgment/frame semaphore field accessors and scanned their direct branches. Its actual consumer, signal and presentation sites remain unresolved; indirect calls are outside the scan. No game code ran on visionOS.

[Measured calibration and next gate](/Users/tip/games/cyberpunk-avp/research/mtkview-calibration-2026-10-10.md).


## Graphics probe result — October 10, 2026

The native/Mac graphics experiment is now built and tested on the physical M2 Vision Pro. Native, retargeted Mac, restarted Mac, and conventional nextDrawable control each passed 120 GPU completions, matching pixels and ordered handoffs, with clean worker/resource shutdown. The eight file-backed sections of the Mac guest remain unchanged after retargeting, path adaptation and signing. This is our own small Metal guest, not Cyberpunk.

Presentation validation remains incomplete: every callback returned zero presentedTime, including both native presentation APIs and the conventional control. The user saw the initial native window and colored rectangle. The strict overall result stays FAIL; the cause of missing timestamps is unresolved. No FPS, stereo or game performance claim follows. Next: calibrate presentation using MTKView and scene visibility, then trace the actual game engine consumer and presentation path.

[Full measured report](/Users/tip/games/cyberpunk-avp/research/graphics-probe-investigation-2026-10-10.md) and [final device results](/Users/tip/games/cyberpunk-avp/research/device-graphics-control-results.json). Previous sections are chronological evidence.


## Metal surface result — October 10, 2026

The focused Mac trace identifies CAMetalLayer creation, a dedicated NSThread/CAMetalDisplayLink loop, and a drawable/texture handoff through two semaphores. The callback signals the view's frame semaphore and waits indefinitely on an engine semaphore. A native host must preserve resource ownership and scheduling; routing that wait through its UI thread would be unsafe.

The installed visionOS SDK compiles the layer/display-link/delegate APIs. Mac MTLCopyAllDevices also compiles, while MTLCopyAllDevicesWithObserver is undeclared in the inspected device SDK. These are compile/static findings, not new headset runtime results. The engine's actual presentation and acknowledgment signal sites remain unidentified; Cyberpunk still has not run on visionOS.

The next minimal experiment is a visible native Metal surface, display-link callbacks on a dedicated thread, and a worker calling an own-code retargeted Mac Metal guest. Compare native versus retargeted guests; verify ordered handoffs, GPU completion, presentation, pixels, timeout behavior and stop/restart on the physical M2. This graphics spike is defined but has not been built.

Detailed [Metal investigation and next probe](/Users/tip/games/cyberpunk-avp/research/metal-surface-investigation-2026-10-10.md), [static trace](/Users/tip/games/cyberpunk-avp/research/mac-metal-trace.json) and [SDK checks](/Users/tip/games/cyberpunk-avp/research/metal-sdk-api-checks.json).

## Executable-host result — October 10, 2026

An own-code macOS ARM64 executable was converted to a library, retargeted, development-signed and run on the physical M2 Vision Pro. Constructor initialization, global pointer relocation, initialized thread-local storage and pthread separation passed; all nine file-backed sections match the original even after signing. The platform-only executable control installed but visionOS rejected dlopen with “cannot dlopen a main executable.” Mac dlopen accepts that same original fixture, so device validation matters.

Focused static tracing now identifies NSApplication startup and delegate setup, NSEvent monitoring, the NSApp event pump, and window/view integration call sites. No game code has been deployed or modified, and this does not predict Cyberpunk performance. Next: trace the Metal surface and frame-loop boundary, then design the larger compatibility host.

Detailed [spike report](/Users/tip/games/cyberpunk-avp/research/executable-loading-spike-2026-10-10.md) and [actual headset results](/Users/tip/games/cyberpunk-avp/research/device-executable-control-results.json). Source is throwaway under /Users/tip/games/scratch/cyberpunk-executable/ and cyberpunk-device-probe/.

## Execution update — October 10, 2026

The supplied Mac2.3 app passed image/full-bundle checks and launched to its main menu on the Mac; storefront entitlement remains unestablished. Later user instructions authorized feasibility execution beyond the original research-only scope.

An own-code visionOS simulator probe passed Metal compute checks and confirmed rejection of an unchanged macOS library. A normal development-signed own-code probe then ran on the physical M2 Vision Pro (visionOS27.2): Metal64-value checks passed, a native framework loaded, and a tiny macOS ARM64 library retargeted to visionOS loaded and returned2077 with unchanged instruction bytes. No game binary or assets were deployed or modified, and Cyberpunk has not run on visionOS.

The game remains a macOS MH_EXECUTE binary requiring process-entry/fixup/TLS handling. Main-AppKit imports number24, plus3 in the AppStore service library; window/event selector references are inventoried. IOKit is partly present in the device SDK and must be assessed per API. The next bounded investigation is executable-host conversion and tracing desktop initialization; the successful minimal library does not prove game compatibility.

Working report: [native loading investigation](/Users/tip/games/cyberpunk-avp/research/native-loading-investigation-2026-10-10.md). Actual device results: [probe results](/Users/tip/games/cyberpunk-avp/research/device-probe-results.json). Reproduction source: /Users/tip/games/scratch/cyberpunk-device-probe/ (throwaway feasibility spike). The device probe is installed and left running.


Date: 2026-10-10. Target: the user's M2 Apple Vision Pro. Cyberpunk is not currently installed. This is a plan for local execution and eventual immersive VR; streaming is outside scope.

## Recommendation

Investigate an ARM64 macOS-to-visionOS compatibility layer before attempting a full game or VR port. Prove local flat gameplay, memory use, and sustained rendering first. Only then build a Metal/Compositor Services stereo integration.

This is an experimental binary-port route, not a source rebuild. A publisher-supported source port remains the strongest production route, but absence of engine source is not evidence that a compatibility experiment is impossible. The earlier discussion was too categorical about that distinction.

Do not promise a playable immersive result on M2, a schedule for a full port, or App Store distribution. Each requires evidence we do not yet have.

## Evidence ledger

| Finding | Evidence | Status and implication |
|---|---|---|
| Cyberpunk has an Apple silicon/Metal Mac version | [CD Projekt Mac launch announcement](https://www.cdprojekt.com/en/media/news/cyberpunk-2077-ultimate-edition-is-available-now-on-mac/) | Verified public documentation. Avoid the Windows x86/D3D12 route for this investigation. |
| Mac minimum is M1/16 GB, targeting 30 fps around 900p; recommended is M3 Pro/18 GB, targeting 60 fps at roughly 1080p | [Mac system requirements](https://support.cdprojektred.com/en/cyberpunk/mac/sp-technical/issue/2891/cyberpunk-2077-mac-system-requirements) | A desktop baseline, not an AVP performance prediction. Storage is documented as 92 GB for GOG/Steam/Epic and 159 GB for App Store, with additional install space. |
| M2 AVP has an 8-core CPU, 10-core GPU, 16 GB unified memory, and 90/96/100 Hz display modes | [Apple M2 AVP specifications](https://support.apple.com/en-us/117810) | Physical capacity is not the app's usable memory budget. Measure physical footprint and system termination behavior on the actual headset. |
| The Mac port uses native libraries, platform-specific archives/shader caches, Metal Shader Converter, MetalFX, and dynamic resolution | [CD Projekt/Apple WWDC26 session](https://developer.apple.com/videos/play/wwdc2026/356/) | Reusing Metal is promising; reusing shipped shader libraries and caches across platforms is an unproven assumption. Crowds and driving can expose CPU pressure as well as GPU pressure. |
| Klepton runs translated guest game code locally on visionOS | [Klepton README](https://github.com/shinyquagsire23/Klepton) | Its documented input is Android ARM64 libraries, with GLES/ANGLE or Vulkan/MoltenVK. It is not a documented macOS Mach-O loader. Reuse lifecycle/input/compositor ideas; add a separate Mac backend if justified. |
| A community Mac Cyberpunk modding stack describes ARM64 engine bindings and Metal overlays | [NightCity Console platform report](https://github.com/ysrdevs/nightcity-console-mac/blob/main/docs/MACOS-MODDING-PLATFORM.md) | Author-reported, tied to Steam v2.3.1. It uses Frida Gadget/MAP_JIT trampolines. Useful hook research, not proof of visionOS-compatible hook installation. The document also describes multiple injection methods; validate against source and an exact build. |
| The selected VR mod is currently built for Windows/D3D12 | [CyberpunkVR Port CMake configuration](https://github.com/dariulone/cyberpunk-vr-port/blob/main/CMakeLists.txt) | Directly observed source uses Win32/DX12 ImGui, MinHook, MASM thunks, Windows libraries, and XR_USE_GRAPHICS_API_D3D12. A recompile with a different SDK is insufficient. |
| The VR mod describes stereo engine views, head tracking, HUD placement, and tracked gameplay | [CyberpunkVR Port README](https://github.com/dariulone/cyberpunk-vr-port) | Author-reported features. Potential reference for camera and gameplay design; Windows addresses, thunks, graphics code, and dependencies must be replaced or re-derived. |
| visionOS supports immersive custom Metal rendering with tracking | [Apple Metal/visionOS session](https://developer.apple.com/videos/play/wwdc2024/10092/) | Supported architecture for a native host. It does not automatically expose another game's render graph. |

## A promising but unverified lead

A developer's [iPhone Cyberpunk demonstration post](https://www.reddit.com/r/EmulationOniOS/comments/1wnsvqq/cyberpunk_is_running_here_on_iphone_17_pro_max/) claims local execution of the Mac game through a JIT-free compatibility layer. The inspected post provides a video/demo claim and Discord link; it does not provide a reproducible release or source repository. It does not demonstrate Vision Pro, immersive stereo, sustained performance, or our device's memory budget. Treat it as a lead to reproduce, not architectural proof. Do not use its claimed resolution or frame rate as an estimate.

No messages were sent to its author or any publisher. An outreach draft can be prepared later if requested.

## Local investigation completed

- Read the local AVP Play README and third-party description at `/Users/tip/Developer/avp-play`. They identify Klepton as the guest toolchain and document local game execution, signing, and device installation. Those project claims were not tested this session.
- Confirmed the XROS 27.0 SDK is installed through `xcrun --sdk xros --show-sdk-version`.
- A Spotlight filename query produced no Cyberpunk matches; that is not an exhaustive filesystem search. The user directly confirmed the game is not installed.
- `xcrun devicectl list devices` timed out initializing CoreDeviceService. This does not establish that the headset is unpaired or absent. Device visibility remains unresolved; retry once outside this tool environment during setup and inspect Xcode if it repeats.
- No game binary was inspected, modified, installed, or executed. No headset build or performance measurement was performed.

## Proposed architecture

```text
Owned, version-pinned Mac game and assets
                 ↓ offline staging on Mac
ARM64 Mach-O compatibility experiment + platform adapters
                 ↓
visionOS host: lifecycle / files / audio / GameController
                 ↓
Existing game Metal renderer → local flat output (first gate)
                 ↓ after engine/render integration is proven
Per-eye camera/render adapter → Compositor Services + ARKit
```

The game, render commands, and assets stay on the headset. A development Mac builds, stages, signs, and deploys; it is not a runtime render server.

### What must be established from the actual artifact

1. Binary identity: storefront, game version, hashes, architecture slices, CPU subtype, Mach-O platform tags, entry point, load commands, signatures and encryption metadata.
2. Dependency closure: embedded libraries and their imports, macOS-only frameworks/classes/selectors, dyld features, C++ runtime requirements, thread-local storage, Objective-C metadata, initialization order, and exception/unwind behavior.
3. Signing/loadability: whether executable code and native libraries can be staged ahead of time, legitimately signed, and loaded by the intended visionOS host on device. A platform-tag rewrite alone is not proof. Do not assume desktop injection, executable mmap, or MAP_JIT will be available.
4. Metal compatibility: availability of imported APIs and GPU features on M2 AVP; whether shipped metallibs load, shaders compile, and representative pipelines execute. Separate reusable shader libraries from platform/device-specific caches. Missing shader source may be a hard blocker.
5. Middleware/store integration: audio/video codecs, compression, networking, saves, user paths, launch authentication, and bundled proprietary components. Preserve purchase checks; do not replace authentication with fake success.
6. VR integration: discover actual Mac camera/render entry points and field layouts. Windows engine offsets and addresses do not transfer. Depth reconstruction or repeating one image is not genuine per-eye rendering.

## Performance policy for the M2 target

Start with ray/path tracing off, low-cost effects, reduced crowds, modest resolution, and gamepad input. These are proposed experimental settings, not a guaranteed preset.

Use a small owned test save in an interior, a dense street, combat, driving, and a heavy expansion area if available. Record CPU/GPU times, frame-time percentiles, physical footprint, allocation failures, loading, thermal behavior, and a 20-minute repeat. Measure stereo separately; its cost need not be exactly twice mono, but it cannot be inferred from mono FPS.

The immersive renderer must meet a documented cadence on the device. Begin by evaluating native 90 Hz (11.11 ms/frame total budget). If an explicitly supported reduced-render cadence/reprojection path is considered, measure it separately and require responsive tracked presentation; do not label desktop 30 fps or frame generation as comfortable VR. Foveation and MetalFX must be validated in the integrated renderer, not enabled by assumption. Do not assume access to raw gaze data.

## Scope and completion gates

- Required final outcome: local Cyberpunk gameplay on M2 Vision Pro with real stereo, tracked head pose, readable HUD, controller input, and measured sustained behavior.
- Intermediate milestones: signed loader proof → local mono title screen → flat playable game → stereo scene → tracked gameplay → repeatable installation.
- A flat game on a local virtual screen is useful evidence but does not complete the immersive goal.
- No streaming fallback. A failed gate produces a recorded blocker, a bounded next experiment, or a source-access requirement.
- Use user-owned game files. Keep staging copies and manifests; never edit the only game install or share bundled game code/assets.
- This research authorizes planning and read-only investigation. It does not authorize purchases, third-party messages, public publication, or device installation.

## Decision

Proceed with a short binary/loader feasibility investigation once a Mac copy is available. Do not begin by porting the Windows VR mod wholesale. If native loading or shader compatibility requires unavailable source, identify the exact failing component and pursue publisher access before expanding the project.

## Game shader and active renderer evidence — October 10, 2026

The physical M2 loaded the unchanged standalone game Metal library and six validated cache samples. Sampled compute pipelines compiled; game shaders were not dispatched. Our controls passed. A hash-matched Mac runtime sample identifies the active direct CAMetalLayer acquisition/presentation path, with a shared indexed drawable slot. A subsequent native app screenshot showed gameplay. No Cyberpunk executable has run on visionOS.

The small headset probe had about 4.98 GiB remaining dirty-memory headroom; this is a lifecycle-dependent snapshot, not a fixed app cap. Mac physical footprint observations ranged from 6.2G to 6.8G. A real native host needs measured memory/resource behavior and AppKit startup, event, view and window translation before mono game startup; stereo and motion controls follow.

Detailed results: [renderer investigation](/Users/tip/games/cyberpunk-avp/research/renderer-integration-2026-10-10.md), [shader samples](/Users/tip/games/cyberpunk-avp/research/shader-cache-samples-2026-10-10.md), [memory limits](/Users/tip/games/cyberpunk-avp/research/shader-memory-budget-2026-10-10.md). Full-cache structural/library-load coverage is underway separately; sample success does not establish complete engine compatibility.

Full-cache follow-up passed on the physical M2: all 20,024 structurally validated Metal library records loaded unchanged, with zero load failures or hash mismatches. There are 8,298 distinct byte identities. This is library loading/enumeration only; no full-cache pipeline compilation, game shader dispatch or game executable execution. [Full report](/Users/tip/games/cyberpunk-avp/research/full-shader-cache-audit-2026-10-10.md). The basic library-loading gate is cleared; native CPU/AppKit hosting remains unresolved.
