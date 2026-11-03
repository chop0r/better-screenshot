#!/bin/bash
# Builds Snappy.app (menu-bar app, no Dock icon) next to this script.
set -e
cd "$(dirname "$0")"
swift build -c release
APP="Better Screenshot.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Snappy "$APP/Contents/MacOS/Snappy"
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Better Screenshot</string><key>CFBundleDisplayName</key><string>Better Screenshot</string>
<key>CFBundleExecutable</key><string>Snappy</string>
<key>CFBundleIdentifier</key><string>com.chopor.snappy</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSScreenCaptureUsageDescription</key><string>Better Screenshot captures screenshots of your screen.</string>
</dict></plist>
PL
codesign --force --sign - "$APP"
echo "Готово: $(pwd)/$APP"
