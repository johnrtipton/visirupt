#!/bin/bash
# Read-only artifact audit. Never launches, patches, re-signs, or copies the game.
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo 'Usage: bash inspect-mac-app.sh /path/to/Game.app /path/to/report-parent' >&2
  exit 2
fi
app=$1
parent=$2
plist="$app/Contents/Info.plist"
[[ -f "$plist" ]] || { echo 'Missing app Info.plist' >&2; exit 2; }
executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")
case "$executable" in
  ''|*/*|.|..) echo 'Invalid CFBundleExecutable' >&2; exit 2 ;;
esac
binary="$app/Contents/MacOS/$executable"
[[ -f "$binary" ]] || { echo 'Missing main executable' >&2; exit 2; }
mkdir -p "$parent"
report=$(mktemp -d "$parent/mac-audit.XXXXXX")
printf '%s\n' "$app" > "$report/app-path.txt"
cp "$plist" "$report/Info.plist"
file "$binary" > "$report/main-file.txt"
shasum -a 256 "$binary" > "$report/main-sha256.txt"
# Optional diagnostics keep their exit status so missing evidence is visible.
capture() {
  local name=$1
  shift
  local status=0
  "$@" > "$report/$name.txt" 2> "$report/$name.stderr.txt" || status=$?
  printf '%s\t%s\n' "$name" "$status" >> "$report/status.tsv"
}
capture architectures xcrun lipo -info "$binary"
capture header xcrun otool -hv "$binary"
capture load-commands xcrun otool -l "$binary"
capture dependencies xcrun otool -L "$binary"
capture imports xcrun nm -u "$binary"
capture signature codesign -dvvv "$binary"
capture entitlements codesign -d --entitlements :- "$binary"
# Inventory embedded native files; detailed import/signature audit is MAIN ONLY.
while IFS= read -r -d '' candidate; do
  description=$(file -b "$candidate")
  case "$description" in
    *Mach-O*) printf '%s\t%s\n' "$candidate" "$description" ;;
  esac
done < <(find "$app/Contents" -type f -print0) > "$report/native-inventory.tsv"
find "$app/Contents" -type f \( -name '*.metallib' -o -name '*.metal' \) -print > "$report/metal-file-paths.txt"
printf '%s\n' 'Static audit only. No runtime, shader rendering, encryption bypass, or visionOS compatibility proven.' > "$report/LIMITATIONS.txt"
printf 'Report: %s\n' "$report"
