#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
staging="$(mktemp -d /private/tmp/pacer-shelf-source.XXXXXX)"
trap 'rm -rf "$staging"' EXIT
rsync -a --exclude .git --exclude .build --exclude output "$root/" "$staging/"
python3 - "$staging/native/Info.plist" <<'PY'
import plistlib, sys
p=sys.argv[1]
with open(p,'rb') as f: info=plistlib.load(f)
info.update(CFBundleIdentifier='com.local.codexpacer.shelf', CFBundleName='Codex Pacer Shelf', CFBundleDisplayName='Codex Pacer Shelf', PacerShelfLocalBuild=True, SUEnableAutomaticChecks=False, SUAutomaticallyUpdate=False)
with open(p,'wb') as f: plistlib.dump(info,f)
PY
mkdir -p "$root/output"
bash "$staging/scripts/native/build-island.sh" "$root/output/Codex Pacer Shelf.app"
