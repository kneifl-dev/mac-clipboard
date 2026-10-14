#!/bin/zsh
# Sestaví MacClipboard.app bez Xcode projektu (stačí Command Line Tools).
#   ./build.sh          – sestaví do build/MacClipboard.app
#   ./build.sh run      – sestaví a spustí
#   ./build.sh install  – sestaví a nainstaluje do /Applications
#   ./build.sh release  – univerzální build (Apple Silicon + Intel) zabalený do dist/*.zip
set -euo pipefail
cd "$(dirname "$0")"

MODE="${1:-}"
APP="build/MacClipboard.app"
BIN="$APP/Contents/MacOS/MacClipboard"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"

compile() { # $1 = architektura, $2 = výstup
  swiftc -O -swift-version 5 -parse-as-library \
    -target "$1-apple-macos13.0" \
    -o "$2" \
    Sources/*.swift
}

if [[ "$MODE" == "release" ]]; then
  compile arm64 build/MacClipboard-arm64
  compile x86_64 build/MacClipboard-x86_64
  lipo -create -output "$BIN" build/MacClipboard-arm64 build/MacClipboard-x86_64
  rm build/MacClipboard-arm64 build/MacClipboard-x86_64
else
  compile "$(uname -m)" "$BIN"
fi

# Podpis: pokud je v klíčence certifikát „MacClipboard Local Signing“, použije se –
# podpis je pak stabilní a povolení ve „Zpřístupnění“ přežije další sestavení.
# Jinak (a vždy pro release) se podepíše ad-hoc.
SIGN_ID="MacClipboard Local Signing"
if [[ "$MODE" != "release" ]] && security find-certificate -c "$SIGN_ID" >/dev/null 2>&1; then
  codesign --force --sign "$SIGN_ID" --identifier cz.kneifl.macclipboard "$APP" 2>&1 | grep -v "replacing existing signature" || true
  echo "✅ Sestaveno a podepsáno certifikátem „$SIGN_ID“: $APP"
else
  codesign --force --sign - --identifier cz.kneifl.macclipboard "$APP" 2>&1 | grep -v "replacing existing signature" || true
  if [[ "$MODE" != "release" ]]; then
    # Ad-hoc podpis se při každém sestavení změní a staré povolení přestane platit
    # (přepínač svítí, ale nefunguje). Smažeme ho, aby se appka zeptala znovu.
    tccutil reset Accessibility cz.kneifl.macclipboard >/dev/null 2>&1 || true
  fi
  echo "✅ Sestaveno (ad-hoc podpis): $APP"
fi

case "$MODE" in
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
  release)
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
    mkdir -p dist
    ZIP="dist/MacClipboard-$VERSION.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "✅ Release: $ZIP ($(lipo -archs "$BIN"))"
    ;;
esac
