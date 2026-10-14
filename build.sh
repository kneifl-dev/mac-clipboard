#!/bin/zsh
# Sestaví MacClipboard.app bez Xcode projektu (stačí Command Line Tools).
#   ./build.sh          – sestaví do build/MacClipboard.app
#   ./build.sh run      – sestaví a spustí
#   ./build.sh install  – sestaví a nainstaluje do /Applications
set -euo pipefail
cd "$(dirname "$0")"

APP="build/MacClipboard.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"

swiftc -O -swift-version 5 -parse-as-library \
  -target "$(uname -m)-apple-macos13.0" \
  -o "$APP/Contents/MacOS/MacClipboard" \
  Sources/*.swift

codesign --force --sign - --identifier cz.kneifl.macclipboard "$APP" >/dev/null
echo "✅ Sestaveno: $APP"

case "${1:-}" in
  run)
    pkill -x MacClipboard 2>/dev/null || true
    open "$APP"
    ;;
  install)
    pkill -x MacClipboard 2>/dev/null || true
    rm -rf /Applications/MacClipboard.app
    cp -R "$APP" /Applications/
    open /Applications/MacClipboard.app
    echo "✅ Nainstalováno do /Applications"
    ;;
esac
