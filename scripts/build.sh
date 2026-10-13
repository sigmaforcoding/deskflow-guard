#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_DIR/dist/Deskflow Guard.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$PROJECT_DIR/Sources/guard.py" "$APP_PATH/Contents/Resources/guard.py"
cat > "$APP_PATH/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.deskflow.guard.manager</string>
<key>CFBundleName</key><string>Deskflow Guard</string>
<key>CFBundleDisplayName</key><string>Deskflow Guard</string>
<key>CFBundleExecutable</key><string>DeskflowGuard</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
xcrun swiftc -parse-as-library -swift-version 6 -warnings-as-errors \
  -target "$(uname -m)-apple-macosx13.0" \
  "$PROJECT_DIR/Sources/Manager.swift" -o "$APP_PATH/Contents/MacOS/DeskflowGuard"
codesign --force --deep --sign - "$APP_PATH"
printf 'Built: %s\n' "$APP_PATH"
