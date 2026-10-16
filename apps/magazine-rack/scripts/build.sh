#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
export CLANG_MODULE_CACHE_PATH=/private/tmp/magazine-rack-module-cache
swift build --package-path "$root" --scratch-path /private/tmp/magazine-rack-build --disable-sandbox -c release
app="$root/output/杂志架.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp -X /private/tmp/magazine-rack-build/arm64-apple-macosx/release/MagazineRack "$app/Contents/MacOS/MagazineRack"
cp -X "$root/Resources/Info.plist" "$app/Contents/Info.plist"
ditto "$root/Resources/EditorialAssets" "$app/Contents/Resources/EditorialAssets"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
