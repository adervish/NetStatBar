#!/bin/bash
set -e

APP="NetStatBar.app"
BINARY="NetStatBar"
ENTITLEMENTS="Sources/NetStatBar/NetStatBar.entitlements"
PROFILE="NetStatBar_new.provisionprofile"   # update filename if needed
DEV_CERT="6165F9CED880F5E960F72E0B2FF242A8E899ECAC"  # Apple Development (valid, non-revoked)
DIST_CERT="Apple Distribution: Alexander Derbes (M74Y8C7TSG)"  # needed for App Store upload

echo "Building..."
swift build -c release 2>&1

echo "Packaging $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp ".build/release/$BINARY" "$APP/Contents/MacOS/"
cp "Info.plist"              "$APP/Contents/"

# Embed provisioning profile
if [ -f "$PROFILE" ]; then
    cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
    echo "Embedded provisioning profile."
else
    echo "WARNING: $PROFILE not found — app will not have wifi-info entitlement."
fi

echo "Signing..."
codesign --force --sign "$DEV_CERT" \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    "$APP/Contents/MacOS/$BINARY"

echo "Done → $APP"
echo ""
echo "To test: open $APP"
echo "Note: grant Location permission on first launch to enable SSID/BSSID reading."
echo "Database: ~/Library/Containers/com.acd.netstatbar/Data/Library/Application Support/NetStatBar/measurements.db"
