#!/usr/bin/env bash
# Bundles the SwiftPM release binary into app/build/iEnvs.app (ad-hoc signed).
# Set VERSION to stamp CFBundleShortVersionString (defaults to 0.1.0).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-0.1.0}"

swift build -c release --package-path app

APP="app/build/iEnvs.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp app/.build/release/iEnvs "$APP/Contents/MacOS/iEnvs"

if [ ! -f app/Resources/AppIcon.icns ]; then
    app/scripts/make-icon.sh
fi
cp app/Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>      <string>iEnvs</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundleIconName</key>        <string>AppIcon</string>
    <key>CFBundleIdentifier</key>      <string>com.hellodeveye.iEnvs</string>
    <key>CFBundleName</key>            <string>iEnvs</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>${VERSION}</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "built: $APP"
echo "run:   open $APP"
