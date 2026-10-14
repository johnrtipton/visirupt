# Native Cyberpunk preparation and deployment

This developer pipeline prepares the supported **Mac ARM64 Cyberpunk 2077 2.3** copy for a native visionOS **2D window**. The recipe is `cyberpunk-mac-2.3-2d-v1`. True game VR remains separate research. Bring your own matching installation; copyrighted game binaries/assets and signing material stay on your machines.

The pipeline has verified private fresh-source preparation and unsigned host/receiver builds. **A normally provisioned build and complete installation using this new CLI on a second Mac/headset are pending.** The existing manually assembled 2D game has human-confirmed gameplay; that evidence does not certify this new installation sequence.

## Prerequisites and private storage

Use an Apple Silicon Mac, Xcode with visionOS SDK **27.0**, XcodeGen, CMake/Ninja, uv and Python 3.11+. Target minimum is visionOS26.0, ARM64 VISIONOS (platform11). Use your own normal Apple development signing team and paired Vision Pro in Developer Mode. This recipe requires both supported memory entitlements in the provisioning profile. Doctor checks local tools/SDK; it cannot guarantee provisioning access.

Keep an immutable original `Cyberpunk2077.app`. The four input hashes and all110 Data hashes are pinned in the public recipe. Unknown game revisions stop. The original Data set is158,461,863,365bytes (147.58GiB). Provide build space and headset space for verified files plus temporary chunks; background initial scheduling requires twice remaining bytes plus512MiB. Capacity reservations are virtual address space, not physical RAM.

The workspace must be **outside both the source checkout and original game tree**, with neither containing the other. Avoid symlinks. Workspaces are private700; JSON/logs are private600. Keep the same workspace to retain installation provenance and transfer owner identity. Never copy its contents into a public repository.

```sh
git clone https://github.com/johnrtipton/visirupt.git
cd visirupt
export GAME='/absolute/path/to/Cyberpunk2077.app'
export WORKSPACE='/absolute/private/path/visirupt-cyberpunk'
export CURL_ARCHIVE='/absolute/path/to/curl-8.14.1.tar.xz'
make doctor
make plan
make prepare
make verify
make status
```

`doctor`/`plan` do not create the workspace or act on a device. `prepare` builds authored providers from source and creates independently verified copies of the original game/providers. Repeated preparation reuses only receipts whose artifacts and dependencies still hash correctly. Corruption invalidates dependent stages; previous diagnostics remain local. `verify` checks all ten prepared frameworks, sections, imports/exports, initializer data and the two declared capacity instructions.

Obtain the exact Curl8.14.1 archive from the URL in `recipes/cyberpunk-mac-2.3-2d-v1.json`; the pinned SHA must match. Alternatively explicitly request the official-source download:

```sh
uv run --no-project python tools/visirupt.py prepare --game "$GAME" --workspace "$WORKSPACE" --download-source
```

Curl8.14.1/SecureTransport is the historical compatibility recipe. Its deprecated backend was removed in later Curl releases; this pin is not a recommendation for a new network application. No command downloads a game.

## Build with your own signing identity

```sh
export TEAM='YOURTEAMID'
make build
```

TEAM must be your actual10-character Apple team identifier. Build requests normal provisioning explicitly, validates the signature/profile and memory capabilities, and independently rechecks final embedded images. Local ad-hoc signatures on private framework copies only make Xcode embedding possible; they do not replace the final provisioned app signature. A build does not install or launch.

## Receiver installation and one-writer transfer

Choose an explicit paired-device identifier; consult your installed `xcrun devicectl list devices --help`. No default headset is supplied.

```sh
export DEVICE='YOUR-PAIRED-DEVICE-IDENTIFIER'
export TRANSPORT='foreground'
uv run --no-project python tools/visirupt.py transfer \
  --workspace "$WORKSPACE" --game "$GAME" --device "$DEVICE" \
  --transport "$TRANSPORT" --team "$TEAM" --deploy-receiver --launch-receiver
```

This is the explicit **first receiver deployment + launch + transfer** operation. Without these two flags, transfer neither installs nor launches. Generating/verifying the private manifest hashes the entire original dataset and keeps only a reviewed arrow-key XML override and its original backup, rather than duplicating all assets locally.

The receiver and final host use `local.games.cyberpunk.assetreceiver` to preserve Application Support/GameData. **Never uninstall as a retry.** The SDK exposes current app/container URLs but does not expose live signing-owner entitlements. Existing applications must match this workspace's completed, normally signed installation record and unchanged system bundle URL. Unknown manual installations, lost provenance or another signing team stop with `CONTAINER_OWNERSHIP_UNKNOWN`; there is no force/reset/migration bypass. Preserve existing research installations and seek a separate migration decision.

Foreground packets are at most256MiB. Keep the receiver window processing requests. Retry the same operation/workspace after interruption; source and received chunk/final hashes are checked. A per-device/container lock and native owner lease exclude competing workspaces and overlapping transports. Pending background jobs retain ownership after lease expiry; do not switch to foreground while those jobs remain pending. Corrupt/unknown persisted activity fails closed.

For background transfer select the Mac's reachable private IPv4 interface, keep it awake on the same network, and run the explicit command above with `--transport background --interface YOUR_LOCAL_IP`. The authenticated range server serves only declared ranges on port8875; private plans contain bearer credentials. The pipeline owns and stops only its server process. OS scheduling controls off-head progress and may require receiver reopening. Changing interface while resuming an existing plan needs deliberate reconciliation; do not invent a new owner to displace queued work.

Once the receiver is installed, open it yourself if needed and resume with:

```sh
make transfer
```

For background mode also `export INTERFACE='YOUR_LOCAL_IP'`. Completion requires the exact native file set, expected sizes, whole-file SHA and verified flags; an offset/progress counter cannot satisfy it.

## Explicit host update and launch

```sh
make install
make launch
```

For a later update after the game host has replaced the receiver, explicitly request a same-owner verifier round trip before the new host update:

```sh
uv run --no-project python tools/visirupt.py install --workspace "$WORKSPACE" --device "$DEVICE" \
  --deploy-receiver --launch-receiver --team "$TEAM"
```

The receiver temporarily replaces only the owned app bundle, retaining its Data container/saves; it verifies native final hashes before the host update. The default install command stops in host state and asks for these explicit flags. Keep the game closed before requesting this update; the command does not independently terminate it.

Install requires a verified signed host and transfer receipt, repeats native final verification, confirms the same signing owner and retained data container, and records an actual successful native installation. Launch requires current owned installation provenance and a complete install stage; it does not terminate another process or claim gameplay. Lost proof after an interrupted installation stops for manual reconciliation. No uninstall, debugger, restart or headset action occurs in local prepare/verify.

## Status and a reviewed reproduction draft

```sh
make status
export REPORT_OUTPUT='/absolute/private/path/new-reproduction-draft.json'
make report
```

Status rehashes completed local stage artifacts; it is not a device health query. Full stage receipts, native tool JSON, transfer checkpoints and diagnostics remain under WORKSPACE (`receipts`, `stages`, `DeviceDiagnostics`, receiver build and transfer directories). Report reconstructs a small typed allowlist rather than scrubbing arbitrary logs. It refuses an existing destination and never uploads/publishes.

Human results default to pending. To record your own observations, create a private JSON object using the keys in `tools/visirupt_pipeline/reports.py:HUMAN` and outcomes `passed`, `failed`, `pending`, `skipped`; `export HUMAN_RESULTS='/absolute/private/path/observations.json'` before `make report`. Passed observations require complete install/launch stages. Tests and launch receipts never infer human gameplay. Review the resulting draft before submitting it publicly; share no saves, account data, credentials, proprietary bytes or raw logs.

## Acceptance matrix for this pipeline

| Gate | Current evidence |
|---|---|
| Synthetic Python source/protocol/privacy checks | Passed locally; CI covers Python3.11/3.14 |
| Swift receiver corruption/recovery and writer leases | Passed host fixtures |
| Fresh source prepare → verify → cache resume | Passed with matching private original inputs; ten frameworks |
| Full private original asset identities | Passed:110 files /158,461,863,365bytes |
| Native unsigned host/receiver build + embedded verification | Passed locally |
| Normally provisioned signed build | Pending; requires an explicit own team |
| New pipeline physical interruption/update/transfer/launch | Pending; no headset action performed during implementation |
| Independent second-Mac/headset gameplay | Pending |
| Audio/save/relaunch, prolonged stability and gameplay FPS | Pending measurement |
| True Cyberpunk VR integration | Research; not part of this2D recipe |

An independent reproduction should record source/recipe/tool/hardware versions; first receiver deployment, interruption/resume, container-preserving host update and launch; actual menu/gameplay; W/A/S/D hold/release, turn/look/fire/scroll; actual output drawable; audio, saves/relaunch and test duration. Preserve failed/superseded findings. Human attribution and AI assistance should be disclosed with the reviewed report. No initial local build counts as independent acceptance.

## Source-only tests

```sh
make automation-test
make -C cyberpunk-avp/resumable test lease-test background-test
```

Public CI uses synthetic inputs and no signing/device secrets, proprietary data or artifact uploads. The private-input integration test is opt-in and skipped by default. These checks are not gameplay benchmarks.
