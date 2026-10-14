# Visirupt

Experimental native porting work for Apple Silicon Mac apps and games on Apple Vision Pro.

**Website:** https://visirupt.com · **Status:** developer checkpoint, not a ready-to-use installer.

Star this repository to show your interest, and watch it for release updates. Contributions and independent reproducibility reports are welcome.

## What works today

The first tested target is the Mac 2.3 build of Cyberpunk 2077 on M2 Vision Pro. Human-confirmed native gameplay includes aiming/firing, WASD movement, arrow-key camera turning, keyboard/mouse input, trackpad scrolling and a plain resizable window. The latest measured output drawable is1280x720. No measured gameplay FPS or extended stability guarantee is available.

This runs in a native visionOS window. Stereo VR, headset pose and spatial controller integration are not yet implemented. Other Mac apps and games are future porting candidates; compatibility is assessed individually.

## What this repository contains

Authored compatibility adapters, native host and loader source, resumable transfer tools, source-only simulator checks and sanitized checkpoint evidence. See [CHECKPOINT.md](CHECKPOINT.md) for the exact source and restore boundaries. The [website and News](https://visirupt.com/news.html) are maintained separately in the private `visirupt-site` repository. Cyberpunk setup and research live in [visirupt-cyberpunk](https://github.com/johnrtipton/visirupt-cyberpunk).

Game executables/assets, proprietary frameworks, original game configuration files, signing keys and compiled apps are not included. Bring your own compatible game copy. The new [native automation pipeline](docs/automation.md) prepares the exact supported inputs and builds providers from source in a private workspace. Fresh local preparation and unsigned builds are verified; a normally provisioned build and independent headset installation through the new CLI remain pending. Use your own signing team.

## Development milestones

- Package and verify a repeatable installation process on another developer's Mac/headset.
- Improve rendering-resolution management and characterize performance.
- Investigate stereo rendering, headset pose and spatial controller integration.
- Validate additional native Mac software with per-app compatibility recipes.

The checkpoint records 95 passing native adapter simulator controls plus receiver/background-transfer tests. Those fixtures do not run original game code and are not gameplay benchmarks.
