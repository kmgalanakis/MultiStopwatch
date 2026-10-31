#!/bin/zsh
# Builds Stopwatches.app in this folder. Run: ./build.sh && open Stopwatches.app
set -euo pipefail
cd "$(dirname "$0")"

# The Command Line Tools lack the SwiftUI macro plugin used by the newest SDK,
# so build against an older SDK where @State is a plain property wrapper.
if [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ] && ! xcode-select -p | grep -q Xcode; then
    export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Stopwatches"

APP="Stopwatches.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Stopwatches"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Stopwatches</string>
    <key>CFBundleDisplayName</key><string>Stopwatches</string>
    <key>CFBundleIdentifier</key><string>com.kmg.stopwatches</string>
    <key>CFBundleExecutable</key><string>Stopwatches</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"
