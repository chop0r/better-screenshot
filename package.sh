#!/bin/bash
# Builds a universal (Apple Silicon + Intel) Better Screenshot.app and wraps it into a .dmg installer.
set -e
cd "$(dirname "$0")"
VERSION="${1:-0.1.0}"
swift build -c release --arch arm64 --arch x86_64
APP="Better Screenshot.app"
rm -rf "$APP" dist
mkdir -p "$APP/Contents/MacOS" dist/stage
cp "$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Snappy" "$APP/Contents/MacOS/Snappy"
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Better Screenshot</string>
<key>CFBundleDisplayName</key><string>Better Screenshot</string>
<key>CFBundleExecutable</key><string>Snappy</string>
<key>CFBundleIdentifier</key><string>com.chopor.snappy</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSScreenCaptureUsageDescription</key><string>Better Screenshot captures screenshots of your screen.</string>
</dict></plist>
PL
codesign --force --sign - "$APP"
cp -R "$APP" dist/stage/
ln -s /Applications dist/stage/Applications
hdiutil create -volname "Better Screenshot" -srcfolder dist/stage -ov -format UDZO "dist/Better-Screenshot-$VERSION.dmg"
rm -rf dist/stage
echo "Готово: $(pwd)/dist/Better-Screenshot-$VERSION.dmg"
