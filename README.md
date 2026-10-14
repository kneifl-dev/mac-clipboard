# Mac Clipboard

A tiny, fully local clipboard history for macOS. It lives in the menu bar, remembers
everything you copy (⌘C) and shows it on **⌃⌘V** (Control + Command + V).

*Malý, plně lokální správce schránky pro macOS – [česky níže](#česky).*

- 🔒 **Memory only** – history is kept in RAM, never written to disk, gone when you quit.
  No network, no telemetry.
- 🙈 Items marked as sensitive by password managers (`org.nspasteboard.ConcealedType` etc.) are skipped.
- 🗂 Shows the content type: text, link, rich text, image, file(s), color.
- 🖼 Small thumbnails for images and image files.
- ⚡ Shows the last 5 items; scroll down to load 5 more at a time.
- ⌨️ Picking an item pastes it straight into the active app (needs Accessibility permission).

## Install

1. Download `MacClipboard-x.y.zip` from [Releases](../../releases) and unzip it.
2. Move `MacClipboard.app` to `/Applications`.
3. The app is not notarized by Apple (that needs a paid developer account), so macOS will block
   the first launch. Either run once in Terminal:
   ```bash
   xattr -dr com.apple.quarantine /Applications/MacClipboard.app
   ```
   or try to open it, then go to *System Settings → Privacy & Security* and click **Open Anyway**.
4. For auto-paste, enable MacClipboard in *System Settings → Privacy & Security → Accessibility*,
   then restart the app. Without it, the selected item is just copied and you paste with ⌘V.

Requires macOS 13 Ventura or newer (Apple Silicon and Intel).

## Usage

| Key | Action |
|---|---|
| ⌃⌘V | open / close |
| scroll, ↑ ↓, PgUp/PgDn | select, load more |
| ↩ or click | paste into the active app |
| 1–9 | quick paste |
| ⌫ | remove item from history |
| esc | close |

The menu bar icon lets you pause recording or clear the history.

## Build from source

Only Xcode Command Line Tools are needed (`xcode-select --install`).

```bash
./build.sh run       # build build/MacClipboard.app and launch it
./build.sh install   # install to /Applications
./build.sh release   # universal build zipped to dist/
```

Ad-hoc signed builds get a new signature every time, so macOS forgets the Accessibility
permission after each rebuild. To avoid that, create a self-signed code signing certificate named
**„MacClipboard Local Signing“** in your login keychain (Keychain Access → Certificate Assistant →
Create a Certificate…, type *Code Signing*) – `build.sh` uses it automatically when present.

## Česky

Malý správce schránky, který žije v menu baru. Pamatuje si vše, co zkopíruješ, **jen v paměti**
(nic na disk, žádná síť), a na **⌃⌘V** ukáže posledních 5 položek s typem obsahu a náhledem.
Scrollováním se načítají další po 5. Výběr položky ji rovnou vloží do aktivní aplikace
(potřebuje povolení v *Nastavení systému → Soukromí a zabezpečení → Zpřístupnění*).

Instalace: stáhni zip z [Releases](../../releases), přesuň appku do Aplikací a při prvním
spuštění ji povol v *Soukromí a zabezpečení → Přesto otevřít* (appka není notarizovaná Applem).

## License

[MIT](LICENSE)

---

*Vibecoded with [Claude Code](https://claude.com/claude-code).* 🤖
