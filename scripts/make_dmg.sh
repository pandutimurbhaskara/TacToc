#!/bin/bash
# Build an ad-hoc-signed universal Release app and a drag-install DMG.
# This script deliberately does NOT claim notarization. See docs/RELEASE.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED="$ROOT/build/release"
DIST="$ROOT/dist"
APP="$DERIVED/Build/Products/Release/TactileMac.app"
STAGE="$DIST/dmg-stage"

rm -rf "$DERIVED" "$STAGE"
mkdir -p "$DIST" "$STAGE"

xcodebuild \
  -project "$ROOT/TactileMac.xcodeproj" \
  -scheme TactileMac \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -destination 'platform=macOS' \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=YES \
  build

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || true)"
if [[ -z "$VERSION" || "$VERSION" == *'$('* ]]; then VERSION="0.1.0"; fi
DMG="$DIST/TactileMac-$VERSION.dmg"
rm -f "$DMG"

ditto "$APP" "$STAGE/TactileMac.app"
ln -s /Applications "$STAGE/Applications"

codesign --verify --deep --strict --verbose=2 "$STAGE/TactileMac.app" || true
codesign -dv --verbose=4 "$STAGE/TactileMac.app" 2>&1 | grep -E 'Identifier|Signature|TeamIdentifier|Runtime Version' || true
printf 'Architectures: '
lipo -archs "$STAGE/TactileMac.app/Contents/MacOS/TactileMac"

hdiutil create \
  -volname "TactileMac" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG"

rm -rf "$STAGE"
shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "Built $DMG"
echo "Signing status: ad-hoc unless a Developer ID identity was supplied by the invoking environment."
