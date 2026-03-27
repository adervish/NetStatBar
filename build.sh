#!/bin/bash
set -e

# Usage:
#   ./build.sh               — dev build, signed for local testing
#   ./build.sh appstore      — App Store distribution build + .pkg for Transporter
#   ./build.sh github        — Developer ID build + notarized .zip for GitHub releases
#
# For github mode, store notarization credentials once with:
#   xcrun notarytool store-credentials "WiFiScout" \
#       --apple-id "your@email.com" \
#       --team-id "M74Y8C7TSG" \
#       --password "app-specific-password"

APP="NetStatBar.app"
BINARY="NetStatBar"
ENTITLEMENTS_DEV="Sources/NetStatBar/NetStatBar-dev.entitlements"
ENTITLEMENTS_DIST="Sources/NetStatBar/NetStatBar.entitlements"
ENTITLEMENTS_GH="Sources/NetStatBar/NetStatBar-developerid.entitlements"

DEV_CERT="6165F9CED880F5E960F72E0B2FF242A8E899ECAC"           # Apple Development (valid)
APP_CERT="Apple Distribution: Alexander Derbes (M74Y8C7TSG)"  # App Store signing
DEV_ID_CERT="Developer ID Application: Alexander Derbes (M74Y8C7TSG)"  # GitHub/direct
PKG_CERT="3rd Party Mac Developer Installer: Alexander Derbes (M74Y8C7TSG)"

DEV_PROFILE="NetStatBar_new.provisionprofile"
DIST_PROFILE="NetStatBar_AppStore.provisionprofile"
NOTARIZE_PROFILE="WiFiScout"   # keychain profile name for notarytool

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
    ENTITLEMENTS="$ENTITLEMENTS_DIST"
elif [ "$MODE" = "github" ]; then
    SIGN_CERT="$DEV_ID_CERT"
    ENTITLEMENTS="$ENTITLEMENTS_GH"
else
    PROFILE="$DEV_PROFILE"
    SIGN_CERT="$DEV_CERT"
    ENTITLEMENTS="$ENTITLEMENTS_DEV"
fi

# Embed provisioning profile (dev and appstore only)
if [ "$MODE" != "github" ]; then
    if [ -f "$PROFILE" ]; then
        cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
        echo "Embedded provisioning profile: $PROFILE"
    else
        echo "WARNING: $PROFILE not found."
    fi
fi

# Strip quarantine xattr
xattr -r -d com.apple.quarantine "$APP" 2>/dev/null || true

echo "Signing ($MODE)..."
codesign --force --deep --sign "$SIGN_CERT" \
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

elif [ "$MODE" = "github" ]; then
    echo ""
    echo "Creating NetStatBar.zip..."
    rm -f NetStatBar.zip
    ditto -c -k --keepParent "$APP" NetStatBar.zip
    echo "Done → NetStatBar.zip"
    echo ""
    echo "Submitting for notarization..."
    xcrun notarytool submit NetStatBar.zip \
        --keychain-profile "$NOTARIZE_PROFILE" \
        --wait
    echo ""
    echo "Stapling notarization ticket..."
    xcrun stapler staple "$APP"
    echo ""
    echo "Re-zipping stapled app..."
    rm -f NetStatBar.zip
    ditto -c -k --keepParent "$APP" NetStatBar.zip
    echo ""
    echo "Done → NetStatBar.zip (notarized, ready for GitHub release)"

else
    echo ""
    echo "To test: open $APP"
    echo "Note: grant Location permission on first launch to enable SSID/BSSID reading."
    echo "Database: ~/Library/Containers/com.acd.netstatbar/Data/Library/Application Support/NetStatBar/measurements.db"
fi
