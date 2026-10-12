# Native Vision Pro VR projects: shortlist and Cyberpunk deferral

Updated: 2026-10-10. Hardware: M2 Apple Vision Pro. Required experience: local execution and rendering on the headset, eventually immersive VR. Streaming is outside scope.

## Decision from this discussion

Defer Cyberpunk 2077 as the starting project. Preserve its [research](cyberpunk-avp-research.md) and [feasibility plan](cyberpunk-avp-plan.md) for later; do not treat them as an active implementation commitment.

Cyberpunk requires an unproven macOS binary compatibility path, proprietary dependencies and shaders, a new native VR integration, and measured M2 resource viability. A smaller source-backed game with existing standalone VR work gives us a better first demonstration and reusable experience with installation, rendering, input, and profiling. This does not mean Cyberpunk has been proved impossible.

## Ranked shortlist

Visual impact and relative effort below are engineering judgments, not measured Vision Pro performance rankings. Older engines and existing standalone VR implementations reduce risk, but each target still needs device validation. These are existing game-to-VR adaptations we can build on, rather than new VR mods from zero.

| Candidate | Why it can impress in VR | Existing foundation | Recommendation |
|---|---|---|---|
| Doom 3, original edition | Dynamic lighting, shadows, detailed interiors, close-range enemies, physical flashlight/PDA interaction | [Doom3Quest](https://github.com/Team-Beef-Studios/Doom3Quest), plus an existing AVP Play recipe | Best first visually convincing baseline; validate and polish the existing route before developing a new engine port |
| Jedi Outcast / Jedi Academy | Motion-controlled lightsabers, laser deflections, Force gestures, recognizable Star Wars environments | [JKXR](https://github.com/Team-Beef-Studios/JKXR), based on OpenJK and OpenXR | Best interaction-focused follow-up; check current Klepton/OpenJK XR support before duplicating work |
| Return to Castle Wolfenstein | Castles, outdoor areas, atmospheric combat, complete campaign | [RTCWQuest](https://github.com/Team-Beef-Studios/RTCWQuest), documented Android ARM64/OpenXR engine port | A bounded porting candidate; confirm compatibility and current support first |
| Half-Life 1 | Environmental scale, scripted events, memorable locations; less modern visual detail | [Lambda1VR](https://github.com/Team-Beef-Studios/Lambda1VR), a Quest adaptation of Xash3D-FWGS | A simpler-looking fallback for validating the full local gameplay loop |

All full-game routes require compatible assets from an owned copy. Engine-source availability does not make commercial game assets freely distributable.

## Doom 3: strongest immediate choice

The Doom3Quest documentation describes a mobile OpenGL ES multiview renderer and VR functionality derived from the Fully Possessed project. It requires the original Doom 3 data; BFG Edition data is not interchangeable with this port. Its upstream Quest build alone does not run on Vision Pro: an adaptation/compatibility layer is still needed. [Upstream documentation](https://github.com/Team-Beef-Studios/Doom3Quest)

Live local inspection found `/Users/tip/Developer/avp-play/recipes/doom3quest.json`:

- Recipe version: Doom3Quest 1.4.8.
- Status marked `verified` by that project, not independently verified in this session.
- Toolchain target: `doom3quest`; minimum fork commit recorded as `108b339`.
- Notes require one render thread to avoid a level-load crash, plus foveation and HUD/PDA support.
- Files include original-game `pak000`–`pak008.pk4`, with checksums tied to the recipe's known files.

The existing recipe makes this a validation-and-polish opportunity before a new porting effort. It does not establish that the current toolchain, the user's headset, and the user's game data have already passed together.

## Jedi Knight: best second choice

JKXR supports Jedi Outcast and Jedi Academy and describes tracked saber motion, collision-based deflections, Force gestures, and VR weapon models. It exposes source and an OpenXR-based Android build. [JKXR documentation](https://github.com/Team-Beef-Studios/JKXR)

[Klepton](https://github.com/shinyquagsire23/Klepton) lists OpenJK XR among its working titles. This is an upstream claim, not proof that a current AVP Play recipe exists or that all JKXR features work on the user's M2 headset. First identify exact compatible source/builds and existing support.

Input is the primary early question. A DualSense supplies sticks and buttons but is not automatically a tracked lightsaber. Decide between supported tracked controllers, hand poses plus gamepad controls, or gamepad-first play, then test the whole gameplay scheme. Do not promise gesture or saber features merely because the upstream Quest version provides them.

## Other possibilities, with a larger integration burden

- Half-Life 2 and Portal could make excellent immersive experiences, but a PC VR mod does not automatically run through a native AVP guest toolchain. Klepton listing a game does not establish that a particular PC VR mod and its runtime dependencies are supported. Keep these as follow-up research rather than the first promise.
- Outer Wilds has [NomaiVR](https://github.com/Raicuparta/nomai-vr), offering impressive planetary scale. Its PC mod setup is not a verified standalone visionOS route; lower graphical demand than Cyberpunk does not solve binary/runtime portability.
- Half-Life: Alyx is already a VR game, not a flat-game VR conversion. The local AVP Play repository contains an Alyx recipe, but it is larger and a less bounded first debugging target than Doom 3. Do not infer performance on this headset from project-reported compatibility.

## Proposed first milestone

Choose Doom 3 for the first device validation. No game downloads, purchases, toolchain changes, or device installation have been performed in this research.

1. Check whether the user owns the original game's compatible data and which controls are available.
2. Confirm the exact AVP Play/Klepton build, device OS, pairing, signing, and recipe identities.
3. Use the existing route to stage copies of the assets and deploy when authorized; do not modify the original installation.
4. Demonstrate local head-tracked stereo gameplay, readable PDA/HUD, input, audio, and save/load.
5. Run a repeatable 20-minute session covering combat, loading transitions, and heavier scenes. Record frame-time distribution, physical footprint, visual faults, and thermal behavior.
6. Measure before enabling high-resolution texture packs or increasing rendering resolution. Improved lighting/texture detail is useful only while the headset maintains comfortable tracking and presentation.
7. Record exact versions and pass/fail results; then decide whether the next project is JKXR interaction work or a new RTCW port.

Completion means a stable demonstration on the user's actual M2 headset, not a successful build or an upstream `verified` label. A decision to defer Cyberpunk is recorded; a replacement game has not yet been selected by the user.
