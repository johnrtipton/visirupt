<!-- extended-va-progress -->
Apple’s supported Extended Virtual Addressing capability makes the original 16 GiB reservation succeed on physical M2 Vision Pro; the same request failed with ENOMEM without it. The original graph now passes the first allocator crash and reaches a later initializer, then crashes while reporting a failed 64-byte PoolDebug allocation. Initializer completion, entrypoint, game frames and VR remain unproven. See research/native-extended-virtual-addressing-2026-10-11.md.
<!-- /extended-va-progress -->

<!-- original-initializer-crash-progress -->
The original physical game graph now reaches its own initializers, then crashes on a null-pointer write in its allocator initialization. All24 directly imported AppKit symbols and the display-mode option are present; five mode-option checks pass on headset and simulator. Original initializer completion, entrypoint and game frame remain unproven. The allocator failure is under investigation. Evidence: research/native-display-mode-option-initializer-crash-2026-10-11.md.
<!-- /original-initializer-crash-progress -->

<!-- workspace-url-progress -->
All 24 directly imported AppKit symbols now resolve in the original physical game probe; the next gate is kCGDisplayShowDuplicateLowResolutionModes. Native URL success/delivery and failure callbacks pass 14 checks on headset and simulator. URL results are asynchronous, with a documented conservative synchronous return. No original initializer completion, entrypoint or game frame. Evidence: research/native-workspace-url-physical-load-2026-10-11.md.
<!-- /workspace-url-progress -->

<!-- tracking-area-progress -->
Tracking-area checks pass 15/15 on M2 Vision Pro and simulator. The original dependency graph now reaches NSWorkspace, with 23/24 imported AppKit symbols present. Actual pointer delivery remains untested; fixture samples were synthetic. No original game frame. Evidence: research/native-tracking-area-physical-load-2026-10-11.md.
<!-- /tracking-area-progress -->

<!-- desktop-menu-tracking-gate-progress -->
The original game dependency probe now reaches NSTrackingArea on M2 Vision Pro (476B4961-20D6-4F9B-8A69-41FAE0E3BB40);22/24 imported AppKit symbols resolve. NSMenu visibility requests concern macOS's absent system menu bar and are explicitly reported unsupported, with actual visibility/capability false. This does not implement in-game menus. Remaining tracking-area behavior needs genuine key-window-gated enter/exit events and responder dispatch;0x21 means entered/exited plus active-in-key-window. NSWorkspace URL handoff also remains. No original game frame exists. Evidence: /Users/tip/games/cyberpunk-avp/research/remaining-appkit-desktop-menu-boundary-2026-10-11.md.
<!-- /desktop-menu-tracking-gate-progress -->

<!-- native-cursor-gaze-progress -->
Native image/cursor adapters pass fourteen cursor checks on M2 Vision Pro and simulator. The original game dependency graph advances to NSMenu (A86DB2F8-66B1-4B4B-A4D9-873C726B173D);21/24 imported AppKit symbols now resolve. Actual trackpad movement/visibility is not yet verified. Eyes and pinch are the intended primary menu interaction; Apple offers privacy-preserving immersive Metal hover targets but does not expose continuous raw gaze coordinates. Game UI target/input integration remains future work. No original game frame exists. Evidence: /Users/tip/games/cyberpunk-avp/research/native-cursor-regions-physical-load-2026-10-11.md.
<!-- /native-cursor-gaze-progress -->

<!-- native-bitmap-image-progress -->
The NSImage bitmap adapter passes eight real pixel/context checks on M2 Vision Pro and the visionOS simulator: transparent cursor image construction, opaque source copying, empty-source preservation, backing scale, nested focus restoration, half-opacity alpha, focus ordering and native ABI. It is compiled into the shared host but not yet staged into the original game graph. Cursor regions and window invalidation are next; no original game frame exists. Evidence: /Users/tip/games/cyberpunk-avp/research/native-image-contracts-2026-10-11.md.
<!-- /native-bitmap-image-progress -->

<!-- appkit-notification-game-progress -->
Physical M2 Vision Pro notification checks pass, and the original game dependency load now advances to missing NSCursor (run 4E5E3D2A-1CEF-4F51-A51D-682A90E765D4). Six AppKit global values match native Mac queries; 19 of 24 directly imported AppKit symbols are present. Scene snapshot and key-state notification ordering are verified in the own probe, with resize and activation test limits documented. The original game has not completed loading or produced a frame. Evidence: /Users/tip/games/cyberpunk-avp/research/appkit-notification-contracts-physical-load-2026-10-11.md.
<!-- /appkit-notification-game-progress -->

<!-- native-window-scene-progress -->
The own window/view host now runs inside a real scene on M2 Vision Pro (run950CC8E1-91A0-43B9-B09E-46FB91CE65BF) and the simulator. Logical guest key-window mapping and native activation agree; a1280x720 Metal clear completes through the attached guest layer. This is host rendering, not a Cyberpunk frame. Screen/monitor geometry, input, styles and remaining original selectors still need work before resolving the main AppKit dependency. No full game graph, entrypoint, gameplay or VR is proven. Evidence: /Users/tip/games/cyberpunk-avp/research/native-window-scene-2026-10-11.md.
<!-- /native-window-scene-progress -->

<!-- galaxy-simulator-progress -->
Galaxy's original adapted copy loaded on the actual visionOS simulator (run 5B2F2052-AD08-4A82-8D7B-23DA19D98BFA). Four genuine native Security adapters are linked; all15 file-backed sections and original code/initializers remain unchanged, with667 chained imports and519187 nlist records verified. The probe calls no exported services or game entrypoint. Physical Galaxy testing and the combined game graph remain next; there is no headset gameplay or VR yet. See local research/galaxy-simulator-load-2026-10-11.md for measured limits.
<!-- /galaxy-simulator-progress -->

# Cyberpunk native Vision Pro feasibility experiment

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

Started 2026-10-10. Target: locally executed Cyberpunk on the user's M2 Vision Pro; no streaming.

## Current evidence

New shader and renderer evidence: all 20,024 structurally validated cache library records load unchanged on the physical M2, with zero failures or hash mismatches; sampled compute pipelines also compile. A hash-matched Mac runtime sample identifies the active direct CAMetalLayer acquisition/presentation path. Memory headroom is a material concern; the game executable still has not run on visionOS. See [results and native host contract](research/renderer-integration-2026-10-10.md).

MTKView calibration: the user confirmed red then green in an open native window. All 120 GPU/pixel/callback checks passed with an active-scene drawing gate and valid GPU timestamps, but all drawable presentation timestamps remained zero. This reproduces the instrumentation issue outside the custom guest/display-link path. See [calibration and consumer follow-up](research/mtkview-calibration-2026-10-10.md). Cyberpunk has not run on visionOS.

Graphics probe now ran on the physical M2: native, retargeted Mac, Mac restart and conventional drawable control each passed 120 GPU/pixel/handoff checks with clean teardown. Every presentation callback still reported zero time, so the strict presentation gate remains failed; the user saw native colored output. See [graphics results and limits](research/graphics-probe-investigation-2026-10-10.md). Cyberpunk itself has not run on visionOS. The earlier next-probe notes below are historical.

Metal follow-up: a focused read-only trace identifies CAMetalLayer creation, a dedicated NSThread/CAMetalDisplayLink loop and drawable/texture semaphore handoff. The relevant display-link APIs compile for visionOS, while the Mac device-observer API is absent from the inspected header. The next own-code graphics probe is defined in [Metal surface investigation](research/metal-surface-investigation-2026-10-10.md); real-device presentation and the game's engine consumer remain untested.

Latest: executable conversion and physical M2 runtime checks passed on our own code, including initialization, relocation, TLS and a pthread worker. The platform-only executable control was rejected by visionOS. Static analysis located Mac startup, event-loop and window/view call sites. See [executable loading spike](research/executable-loading-spike-2026-10-10.md). Cyberpunk itself has not run on visionOS. Initial source-audit notes below are historical.

Update: the supplied DMG download is now complete and passed image CRC checks. Its bundle was inspected read-only: ARM64 macOS, version 2.3.0, with three ARM64 native libraries and Apple renderer imports. Signature and entitlements checks must run outside the sandbox: the main executable and all three libraries verify successfully there, with Apple Mac OS Application Signing. The earlier sandbox diagnostics were misleading. The user approved normal Mac launch; macOS verification completed and the Cyberpunk 2.3 / Phantom Liberty main menu rendered successfully. Gameplay and performance remain unmeasured. See [the artifact audit](research/mac-artifact-audit.md) and [identity manifest](research/artifact-manifest.json). Camera-named symbols are discovery leads, not validated hooks. The original initial notes below describe the state before this artifact became available.

- Public VR mod downloaded to `../scratch/cyberpunk-vr/upstream`, pinned at `a0c23fe110530bb74a73b3adf1ffa7d83050c43d`. Source checkout is unchanged. Submodules were not fetched; no build attempted.
- Development Mac: M2 Max MacBook Pro, 64 GB RAM, ARM64. Available disk: approximately 381 GiB at inspection. XROS SDK: 27.0. Device OS, pairing, signing team, and memory budget have not been checked in this experiment.
- No Cyberpunk app found in the bounded `/Applications` name check. User previously stated the game was not installed. Other drives and storefront libraries have not been exhaustively scanned. Storefront/ownership question is pending.
- Read-only artifact inspector prepared in `tools/inspect-mac-app.sh`. Validated using a synthetic app containing a copy of `/usr/bin/true`, not the game: all seven diagnostic commands returned zero; main hash matched the original; native-file inventory populated. This proves the collection tool on that fixture only.

## Source map and reuse boundary

Paths below are relative to the pinned upstream checkout.

| Component | Inspected source | Observation and next requirement |
|---|---|---|
| Build/plugin entry | `CMakeLists.txt`, `src/Main.cpp` | Windows DLL, RED4ext, D3D12 device/queue initialization. Mac plugin loading and engine lifecycle entry must be established independently. |
| Camera FOV/pitch | `src/Hooks/CameraFov.cpp`, `src/Hooks/CameraPitch.cpp` | Windows byte signatures, x86 machine-code trampoline construction, direct camera field access. Those signatures cannot locate ARM64 Mac functions. Recover equivalent functions and validate field semantics before writing them. |
| Camera math | `src/Camera/CameraMath.cpp` | Useful IPD/world-scale relationships, but this file also imports Windows, OpenXR, RED4ext, and hook facilities. It is a conceptual reference, not a platform-neutral module ready to compile. FOV comments differ across inspected files; verify actual live semantics rather than copying comments as fact. |
| Hook discovery | `include/Utils/AobScanner.hpp` | Windows module/virtual-memory APIs. Mac discovery requires Mach-O-aware evidence and exact-build validation. |
| Stereo engine view | `src/Stereo/FrameGraph.cpp` | Second-view RTT component, raw offsets, engine view identity, D3D types and detours. Need Mac RTT/render-graph equivalence and separate per-eye correctness. |
| XR pacing | `src/Runtimes/OpenXRFrameLoop.cpp` | OpenXR frame cycle and D3D12 eye resources. Native visionOS frame timing and Metal presentation must replace platform-specific integration. |
| Gameplay/scripts | `mods/`, `src/Natives/` | Potentially reusable interaction designs. Script/native bridge and asset compatibility remain untested; no portability claim made. |

Static review establishes platform coupling, not inability to port. No game binary or runtime has been inspected, no mod has been loaded, and no headset performance has been measured.

## Next experiment

1. Establish the user's legitimate Mac storefront and installation path. Do not purchase automatically.
2. Inspect the installed bundle without launching or modifying it:

   ```sh
   bash /Users/tip/games/cyberpunk-avp/tools/inspect-mac-app.sh "/actual/path/Cyberpunk.app" /Users/tip/games/scratch/cyberpunk-vr/game-reports
   ```

3. Review architecture, platform load commands, imported libraries, signature/entitlements, embedded native files, and Metal-library paths. The initial tool collects detailed diagnostics for the main executable only; follow with embedded-library audits.
4. Decide the exact Mac loading/instrumentation experiment from that evidence. First prove a minimal camera/FOV observation on Mac; do not begin motion controls or guess engine offsets.
5. Independently prove a normally signed, local visionOS execution path. A successful Mac camera hook would not prove that the game can execute on visionOS.

The prior full plan remains at `/Users/tip/ai/games/cyberpunk-avp-plan.md`. This source audit is a prerequisite addendum, not completion of its game/device gates. We reordered the source review because the newly supplied mod can be inspected before a Mac game installation exists. Risk: reuse estimates stay provisional until comparison with the actual Mac build.

## Boundaries

Keep original game files and saves intact. Reports are local and may contain user paths. Do not distribute game binaries. No runtime memory patches, signing changes, headset installation, purchases, or external publication have been performed.

## Simulator feasibility result — October 10, 2026

The throwaway native visionOS simulator probe built and ran. Its bundled Metal compute shader passed all64 value checks. A simulator-targeted ARM64 library loaded, while a macOS-targeted ARM64 library built from the same own-code source was rejected as an incompatible platform. Cyberpunk itself was not loaded in the simulator. See [measured results and next gate](research/simulator-feasibility-2026-10-10.md).

## M2 device loading result — October 10, 2026

The own-code development-signed probe ran on the physical M2 Vision Pro. Metal64-value checks passed, a native framework loaded, and a tiny macOS ARM64 library retargeted to visionOS loaded and returned the expected2077. Cyberpunk itself remains untested on visionOS; the executable startup and AppKit/event/library adaptations are separate gates. See [native loading investigation](research/native-loading-investigation-2026-10-10.md).
