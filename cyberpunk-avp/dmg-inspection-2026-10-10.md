# Supplied Cyberpunk image inspection

## Download diagnosis update

Authenticated SharePoint byte-range request established total size **153,668,539,600 bytes**. The local file was only 67,923,335,402 bytes. The last 1 MiB of that partial file matches the same source range exactly. This establishes an incomplete local transfer rather than merely an unrecognized image. Chrome displayed a finished download despite that smaller file.

Resumed transfer into the original Downloads path after preserving an APFS clone at `/Users/tip/games/scratch/cyberpunk-vr/Cyberpunk.partial.backup.dmg`. Transfer was verified growing. Completion, final image validity, and game contents remain pending. Status evidence: `/Users/tip/games/context/terminal/cyberpunk-resume-20261010.log`. Credentials excluded.

## Initial inspection

Target: `/Users/tip/Downloads/Cyberpunk.2077.v2.3.Incl.DLC.MacOS-ARM.dmg`.

Read-only results:

- File exists and is readable; size 67,923,335,402 bytes (~63.26 GiB), stable over two observations. Modification time Oct 10 2026 16:16:29 (host-reported local time).
- `file` identifies LZFSE/LZVN compressed bytes; first four bytes are `bvxn`.
- `hdiutil attach -readonly -nobrowse -noautoopen` failed with `image not recognized`, including after approved execution outside the sandbox. No mounted volume resulted.
- Initial sandbox `hdiutil imageinfo` and `diskutil image info` failed due to unavailable device/framework access; these are not evidence of file corruption. The separate outside-sandbox attach failure is stronger evidence of an image parsing problem.
- Installed p7zip 17.05 could not open it as a DMG. This older tool's failure is not conclusive by itself.
- Apple Archive `aa list` rejected it as an invalid/unsupported archive stream. Log: `context/terminal/cyberpunk-dmg-aa-list-20261010.log` relative to workspace root.
- The first four bytes of the final 512-byte region are not `koly`; a conventional UDIF trailer was not found at that expected position. This bounded check is consistent with truncation or nonstandard packaging, not proof of either.
- REA `open_binary` returned `target_unavailable`; no analysis session opened.

Unknown: complete download status, source packaging, expected file size/checksum, actual game content, game architecture/version/signature, embedded shader/dependency compatibility. ARM in the filename has not been validated against an executable.

No game files extracted, launched, installed, changed, or re-signed. No runtime or headset test performed.

Next: confirm download completion and compare the source's expected size/hash, or supply the actual installed Mac app bundle. Do not attempt to repair or guess-install this image from the current evidence.
