#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-0.1.0-preview.1}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]] || { echo 'Invalid version' >&2; exit 1; }
APP="dist/Tangerine.app"
[[ -d "$APP" ]] || { echo 'Build the app first with scripts/build-app.sh' >&2; exit 1; }
codesign --verify --deep --strict "$APP"
ARCH="$(lipo -archs "$APP/Contents/MacOS/Tangerine" | tr ' ' '-')"
MINIMUM="$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$APP/Contents/Info.plist")"
NAME="Tangerine-Studio"
[[ -x .venv/bin/dmgbuild ]] || { echo 'Run scripts/bootstrap.sh first (dmgbuild is required).' >&2; exit 1; }
STAGING="$(mktemp -d "$PWD/.build/dmg.XXXXXX")"
MOUNTED=0
cleanup() {
    if [[ "$MOUNTED" == 1 ]]; then hdiutil detach "$STAGING/mounted" >/dev/null; fi
    rm -rf "$STAGING"
}
trap cleanup EXIT
mkdir -p "$STAGING/volume"
ditto "$APP" "$STAGING/volume/Tangerine.app"
swift scripts/make-dmg-background.swift "$STAGING/volume/installer.tiff"
TANGERINE_DMG_STAGING="$STAGING/volume" .venv/bin/dmgbuild \
    -s scripts/dmg-settings.py "Tangerine Studio $VERSION" "$STAGING/$NAME.dmg"
hdiutil verify "$STAGING/$NAME.dmg"
mkdir "$STAGING/mounted"
hdiutil attach -readonly -nobrowse -mountpoint "$STAGING/mounted" "$STAGING/$NAME.dmg"
MOUNTED=1
.venv/bin/python scripts/verify-bundle.py "$STAGING/mounted/Tangerine.app"
hdiutil detach "$STAGING/mounted"
MOUNTED=0
mkdir -p dist
mv "$STAGING/$NAME.dmg" "dist/$NAME.dmg"
(cd dist && shasum -a 256 "$NAME.dmg" > "$NAME.dmg.sha256")
echo "Built dist/$NAME.dmg (macOS $MINIMUM, $ARCH)"
