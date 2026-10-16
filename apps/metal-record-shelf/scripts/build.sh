#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
export CLANG_MODULE_CACHE_PATH=/private/tmp/metal-record-shelf-module-cache
swift build --package-path "$root" --scratch-path /private/tmp/metal-record-shelf-build --disable-sandbox -c release
app="${RECORD_SHELF_OUTPUT:-$root/output/金属唱片架.app}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/Runtime" "$app/Contents/Resources/Backend"
cp -X /private/tmp/metal-record-shelf-build/arm64-apple-macosx/release/MetalRecordShelf "$app/Contents/MacOS/MetalRecordShelf"
cp -X "$(node -p 'process.execPath')" "$app/Contents/Resources/Runtime/node"
cp -X "$root/Backend/request.cjs" "$root/Backend/package.json" "$root/Backend/package-lock.json" "$app/Contents/Resources/Backend/"
rsync -a --delete "$root/Backend/node_modules/" "$app/Contents/Resources/Backend/node_modules/"
cp -X "$root/Resources/Info.plist" "$app/Contents/Info.plist"
cp -X "$root/Resources/Node-LICENSE.txt" "$app/Contents/Resources/Node-LICENSE.txt"
cp -X "$root/Resources/THIRD_PARTY.txt" "$app/Contents/Resources/THIRD_PARTY.txt"
if [[ -f "$root/Resources/RecordShelf.icns" ]]; then cp -X "$root/Resources/RecordShelf.icns" "$app/Contents/Resources/RecordShelf.icns"; fi
codesign --force --sign - "$app/Contents/Resources/Runtime/node"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
printf 'App: %s\n' "$app"
