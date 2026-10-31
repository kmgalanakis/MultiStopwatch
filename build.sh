#!/bin/zsh
# Builds Multi-Stopwatch.app in this folder. Run: ./build.sh && open Multi-Stopwatch.app
set -euo pipefail
cd "$(dirname "$0")"

# The Command Line Tools lack the SwiftUI macro plugin used by the newest SDK,
# so build against an older SDK where @State is a plain property wrapper.
if [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ] && ! xcode-select -p | grep -q Xcode; then
    export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi

# UNIVERSAL=1 builds for Apple silicon and Intel. VERSION sets the app version.
ARCH_FLAGS=()
if [ "${UNIVERSAL:-0}" = "1" ]; then ARCH_FLAGS=(--arch arm64 --arch x86_64); fi
VERSION="${VERSION:-1.0}"

swift build -c release "${ARCH_FLAGS[@]}"
BIN="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)/Stopwatches"

APP="Multi-Stopwatch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Stopwatches"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Multi-Stopwatch</string>
    <key>CFBundleDisplayName</key><string>Multi-Stopwatch</string>
    <key>CFBundleIdentifier</key><string>com.kmg.stopwatches</string>
    <key>CFBundleExecutable</key><string>Stopwatches</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"
