#!/bin/bash
set -e

# Usage: ./build.sh [appstore]
#   (no arg) = dev build, signed for local testing
#   appstore  = App Store distribution build + .pkg

APP="NetStatBar.app"
BINARY="NetStatBar"
ENTITLEMENTS="Sources/NetStatBar/NetStatBar.entitlements"

DEV_CERT="6165F9CED880F5E960F72E0B2FF242A8E899ECAC"           # Apple Development (valid)
APP_CERT="3rd Party Mac Developer Application: Alexander Derbes (M74Y8C7TSG)"
PKG_CERT="3rd Party Mac Developer Installer: Alexander Derbes (M74Y8C7TSG)"

DEV_PROFILE="NetStatBar_new.provisionprofile"                  # Development profile
DIST_PROFILE="NetStatBar_AppStore.provisionprofile"            # App Store profile (download from portal)

MODE="${1:-dev}"

echo "Building (release)..."
swift build -c release 2>&1

echo "Packaging $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp ".build/release/$BINARY" "$APP/Contents/MacOS/"
cp "Info.plist"              "$APP/Contents/"
cp "AppIcon.icns"            "$APP/Contents/Resources/"

if [ "$MODE" = "appstore" ]; then
    PROFILE="$DIST_PROFILE"
    SIGN_CERT="$APP_CERT"
else
    PROFILE="$DEV_PROFILE"
    SIGN_CERT="$DEV_CERT"
fi

# Embed provisioning profile
if [ -f "$PROFILE" ]; then
    cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
    echo "Embedded provisioning profile: $PROFILE"
else
    echo "WARNING: $PROFILE not found."
fi

echo "Signing ($MODE)..."
codesign --force --sign "$SIGN_CERT" \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    "$APP/Contents/MacOS/$BINARY"

codesign --force --sign "$SIGN_CERT" \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    "$APP"

echo "Done → $APP"

if [ "$MODE" = "appstore" ]; then
    echo ""
    echo "Building .pkg for App Store upload..."
    productbuild \
        --component "$APP" /Applications \
        --sign "$PKG_CERT" \
        NetStatBar.pkg
    echo "Done → NetStatBar.pkg"
    echo ""
    echo "Next: open Transporter.app and drag NetStatBar.pkg to upload to App Store Connect."
else
    echo ""
    echo "To test: open $APP"
    echo "Note: grant Location permission on first launch to enable SSID/BSSID reading."
    echo "Database: ~/Library/Containers/com.acd.netstatbar/Data/Library/Application Support/NetStatBar/measurements.db"
fi
