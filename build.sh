#!/bin/bash
set -e

APP="NetStatBar.app"
BINARY="NetStatBar"

echo "Building..."
swift build -c release 2>&1

echo "Packaging $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp ".build/release/$BINARY" "$APP/Contents/MacOS/"
cp "Info.plist"              "$APP/Contents/"

echo "Done → $APP"
echo ""
echo "To run:    open $APP"
echo "To install: cp -r $APP /Applications/"
