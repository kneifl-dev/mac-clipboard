#!/bin/bash
# Mac Clipboard – install / update with one command:
#   curl -fsSL https://raw.githubusercontent.com/kneifl-dev/mac-clipboard/main/install.sh | bash
# Uninstall:
#   curl -fsSL https://raw.githubusercontent.com/kneifl-dev/mac-clipboard/main/install.sh | bash -s -- --uninstall
set -euo pipefail

REPO="kneifl-dev/mac-clipboard"
APP_NAME="MacClipboard.app"
BUNDLE_ID="cz.kneifl.macclipboard"
DEST="${MACCLIPBOARD_DIR:-/Applications}"

say() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
die() { printf '\033[1;31mError:\033[0m %s\n' "$1" >&2; exit 1; }

[[ "$(uname)" == "Darwin" ]] || die "Mac Clipboard runs only on macOS."
major=$(sw_vers -productVersion | cut -d. -f1)
(( major >= 13 )) || die "Mac Clipboard needs macOS 13 Ventura or newer."

if [[ "${1:-}" == "--uninstall" ]]; then
  pkill -x MacClipboard 2>/dev/null || true
  for dir in /Applications "$HOME/Applications"; do
    if [[ -d "$dir/$APP_NAME" ]]; then
      "$dir/$APP_NAME/Contents/MacOS/MacClipboard" --disable-login-item 2>/dev/null || true
      rm -rf "${dir:?}/$APP_NAME"
    fi
  done
  tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
  defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
  say "Mac Clipboard was removed."
  exit 0
fi

# Without admin rights fall back to ~/Applications.
if [[ ! -w "$DEST" ]]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

say "Downloading the latest Mac Clipboard…"
curl -fsSL "https://github.com/$REPO/releases/latest/download/MacClipboard.zip" -o "$TMP/MacClipboard.zip" \
  || die "Download failed. Check your internet connection."
ditto -x -k "$TMP/MacClipboard.zip" "$TMP/unzipped"
[[ -d "$TMP/unzipped/$APP_NAME" ]] || die "The downloaded archive doesn't contain $APP_NAME."

UPDATING=false
[[ -d "$DEST/$APP_NAME" ]] && UPDATING=true

pkill -x MacClipboard 2>/dev/null || true
rm -rf "${DEST:?}/$APP_NAME"
ditto "$TMP/unzipped/$APP_NAME" "$DEST/$APP_NAME"
# The app isn't notarized by Apple – make sure Gatekeeper doesn't block it.
xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true

if $UPDATING; then
  # A new build has a new signature, so the old Accessibility permission would silently stop working.
  tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
  say "Updated $DEST/$APP_NAME"
else
  say "Installed to $DEST/$APP_NAME"
fi

if [[ -z "${MACCLIPBOARD_NO_OPEN:-}" ]]; then
  open "$DEST/$APP_NAME"
fi

say "Done! Look for the clipboard icon in the menu bar and press ⌃⌘V (Control + Command + V)."
if $UPDATING; then
  say "Please re-enable Mac Clipboard in System Settings → Privacy & Security → Accessibility for auto-paste."
fi
