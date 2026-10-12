# Native Cyberpunk Vision Pro checkpoint — 2026-10-12

Local checkpoint of the experimental Mac 2.3-to-visionOS port. No remote or public distribution is configured.

Human confirmed native gameplay on M2 Vision Pro: aiming/firing, WASD movement with release, arrow-key horizontal camera turning, click/drag/trackpad scrolling, and a plain resizable window. Latest native output is 1280x720, up from 640x360; user reports responsive gameplay. FPS, internal render targets and extended stability are not measured. Window resizing enlarges presentation, but backing render resolution remains fixed. Stereo VR and head/controller tracking are not implemented.

## Included

- `cyberpunk-avp/compat`: authored native platform adapters.
- `cyberpunk-avp/resumable`: resumable asset receiver and transfer/test source.
- `scratch/cyberpunk-staged-startup`: active app, loader/path/memory controls, forwarding diagnostics and XcodeGen spec.
- `scratch/cyberpunk-consolidated-host`: adapter framework XcodeGen spec and display bridge source.
- `scratch/cyberpunk-window-init-simulator`: source-only native adapter regression harness.
- `checkpoint/2026-10-12`: current plan/research snapshots, 95 passing simulator controls, physical acceptance evidence, actual native drawable trace and camera-binding patch.

## Restore boundary

The running workspace is `/Users/tip/games`. Sources retain their existing relative layout. XcodeGen can regenerate the excluded Xcode projects from their specs. The current Makefile builds adapters and the native app using the local external frameworks, or the source-only simulator harness.

Game module/assets, provider frameworks, compiled apps/libraries, DerivedData, signing keys/profiles, raw crashes and transfer credentials are excluded. This commit is an authored-source/evidence checkpoint, not a standalone redistributable game or a fully self-contained fresh-machine build. Current native frameworks and the full asset source app remain outside Git. Never rebuild the full-data source app DerivedData. External framework hashes are recorded for identification only.

Do not uninstall `local.games.cyberpunk.assetreceiver`: its data container holds the native game assets and saves. Normal app updates preserve that container. No headset restart/installation is performed for this checkpoint.

One active native `r6/config/inputUserMappings.xml` intentionally differs from its original transfer hash: two arrows were added to RightX_Axis, preserving the pad binding. The patch and both hashes are included; the complete original/modified game XML and archives are not. Original backup remains under the Dropbox games `scratch/cyberpunk-input` folder.

## Verification

Latest complete source-only simulator result: 95 controls passed; original game code is not executed by that fixture. Current device app build and deep/strict signature verification passed before installation, and the user confirmed the installed build. No gameplay FPS benchmark is inferred from Metal submission counts. Earlier README/research findings describe historical intermediate states; the checkpoint acceptance records take precedence for current status.

Fresh pre-commit verification: simulator rebuild and all95 controls passed; receiver core checks passed; six background-transfer unit tests passed. No physical-game installation or interruption was performed.
