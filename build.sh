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

# Podpis: pokud je v klíčence certifikát „MacClipboard Local Signing“, použije se –
# podpis je pak stabilní a povolení ve „Zpřístupnění“ přežije další sestavení.
# Jinak se podepíše ad-hoc (povolení po každém sestavení přestane platit).
SIGN_ID="MacClipboard Local Signing"
if security find-certificate -c "$SIGN_ID" >/dev/null 2>&1; then
  codesign --force --sign "$SIGN_ID" --identifier cz.kneifl.macclipboard "$APP" 2>&1 | grep -v "replacing existing signature" || true
  echo "✅ Sestaveno a podepsáno certifikátem „$SIGN_ID“: $APP"
else
  codesign --force --sign - --identifier cz.kneifl.macclipboard "$APP" 2>&1 | grep -v "replacing existing signature" || true
  # Ad-hoc podpis se při každém sestavení změní a staré povolení přestane platit
  # (přepínač svítí, ale nefunguje). Smažeme ho, aby se appka zeptala znovu.
  tccutil reset Accessibility cz.kneifl.macclipboard >/dev/null 2>&1 || true
  echo "✅ Sestaveno (ad-hoc podpis): $APP"
fi

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
