#!/usr/bin/env bash
# Bundles the SwiftPM release binary into app/build/iEnvs.app (ad-hoc signed).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

swift build -c release --package-path app

APP="app/build/iEnvs.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp app/.build/release/iEnvs "$APP/Contents/MacOS/iEnvs"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>      <string>iEnvs</string>
    <key>CFBundleIdentifier</key>      <string>com.hellodeveye.iEnvs</string>
    <key>CFBundleName</key>            <string>iEnvs</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>0.1.0</string>
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
