#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -x .venv/bin/pyinstaller ]] || { echo 'Run scripts/bootstrap.sh first.' >&2; exit 1; }
APP="dist/Tangerine.app"
# Build in a staging directory so a failed build preserves the previous app.
mkdir -p .build
STAGING="$(mktemp -d "$PWD/.build/app.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
swift scripts/make-brandmark.swift
swift build -c release
SWIFT_BIN="$(swift build -c release --show-bin-path)"
.venv/bin/pyinstaller --noconfirm --clean --onedir --name tangerine-engine \
    --distpath "$STAGING/frozen" --workpath "$STAGING/pyinstaller" --specpath "$STAGING" \
    --collect-all pillow_heif --collect-all pymupdf \
    --hidden-import PIL.AvifImagePlugin --hidden-import PIL.BmpImagePlugin \
    --hidden-import PIL.WebPImagePlugin --hidden-import PIL.TiffImagePlugin \
    Resources/engine.py
CONTENTS="$STAGING/Tangerine.app/Contents"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$SWIFT_BIN/Tangerine" "$CONTENTS/MacOS/Tangerine"
cp -R "$SWIFT_BIN/Tangerine_Tangerine.bundle" "$CONTENTS/Resources/"
swift scripts/make-icon.swift "$STAGING/AppIcon.iconset"
iconutil -c icns "$STAGING/AppIcon.iconset" -o "$CONTENTS/Resources/AppIcon.icns"
cp Resources/Info.plist "$CONTENTS/Info.plist"
mv "$STAGING/frozen/tangerine-engine" "$CONTENTS/Resources/engine"
.venv/bin/python scripts/bundle_native.py "$CONTENTS/Resources/engine"
OFFICE_APP="${TANGERINE_OFFICE_APP:-/Applications/LibreOffice.app}"
if [[ -d "$OFFICE_APP" ]]; then
    ditto "$OFFICE_APP" "$CONTENTS/Resources/engine/LibreOffice.app"
else
    if [[ "${ALLOW_NO_OFFICE:-0}" != 1 ]]; then
        echo 'LibreOffice is required for a complete build. Install it, or set TANGERINE_OFFICE_APP to its .app path.' >&2
        echo 'For a development build without office conversions, set ALLOW_NO_OFFICE=1.' >&2
        exit 1
    fi
fi
cp LICENSE THIRD_PARTY_NOTICES.md requirements.txt "$CONTENTS/Resources/"
# Keep package provenance without embedding developer-local installation paths.
.venv/bin/python -m pip inspect | .venv/bin/python -c '
import json, sys
manifest = json.load(sys.stdin)
for package in manifest.get("installed", []):
    package.pop("metadata_location", None)
    package.pop("direct_url", None)
json.dump(manifest, sys.stdout, indent=2)
' > "$CONTENTS/Resources/dependency-manifest.json"
.venv/bin/python scripts/audit_bundle.py "$STAGING/Tangerine.app"
# Ad-hoc signing supports local testing. See docs/RELEASING.md for public releases.
codesign --force --deep --sign - "$STAGING/Tangerine.app"
codesign --verify --deep --strict "$STAGING/Tangerine.app"
mkdir -p dist
if [[ -d "$APP" ]]; then mv "$APP" "$STAGING/previous.app"; fi
mv "$STAGING/Tangerine.app" "$APP"
echo "Built $PWD/$APP"
