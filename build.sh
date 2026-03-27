#!/bin/bash
set -e

APP="NetStatBar.app"
BINARY="NetStatBar"
ENTITLEMENTS="Sources/NetStatBar/NetStatBar.entitlements"

echo "Building..."
swift build -c release 2>&1

echo "Packaging $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp ".build/release/$BINARY" "$APP/Contents/MacOS/"
cp "Info.plist"              "$APP/Contents/"

echo "Signing..."
# NOTE: wifi-info entitlement is temporarily omitted — requires a macOS provisioning
# profile to use with Developer ID signing. BSSID will show "—" until resolved.
# To re-enable: add --entitlements "$ENTITLEMENTS" once provisioning profile is set up.
codesign --force --sign "Developer ID Application: Alexander Derbes (M74Y8C7TSG)" \
    "$APP/Contents/MacOS/$BINARY"

echo "Done → $APP"
echo ""
echo "To run:    open $APP"
echo "To install: cp -r $APP /Applications/"
echo ""
echo "Database: ~/Library/Application Support/NetStatBar/measurements.db"
