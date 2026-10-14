# Mac Clipboard

Malý, plně lokální správce schránky pro macOS. Žije v menu baru, pamatuje si
všechno, co zkopíruješ (⌘C), a na zkratku **⌃⌥V** (Control + Option + V) ukáže
okno s posledními 5 položkami – včetně typu obsahu. Další položky zobrazíš
tlačítkem *Zobrazit více* (nebo šipkou dolů) a scrolluješ v nich.

## Soukromí
- **Nic se neukládá na disk** – historie je jen v paměti (RAM, max. 100 položek)
  a po ukončení aplikace zmizí.
- Žádná síť, žádná telemetrie.
- Položky označené password managery jako citlivé (`org.nspasteboard.ConcealedType`
  apod.) se neukládají vůbec.
- V menu baru jde ukládání kdykoli pozastavit nebo historii vymazat.

## Podporované typy
Text · Odkaz · Formátovaný text (RTF/HTML) · Obrázek · Soubor(y) z Finderu · Barva · Jiné.
Při vložení se vrátí všechny původní formáty (např. formátování zůstane zachované).

## Ovládání okna
| Klávesa | Akce |
|---|---|
| ⌃⌥V | otevřít / zavřít |
| ↑ ↓ (PgUp/PgDn) | výběr |
| ↩ nebo klik | vložit do aktivní aplikace |
| 1–9 | rychlé vložení položky |
| ⌫ | odstranit položku z historie |
| esc | zavřít |

## Sestavení a spuštění
Stačí Command Line Tools (Xcode není potřeba), macOS 13+.

```bash
./build.sh run       # sestaví build/MacClipboard.app a spustí
./build.sh install   # nainstaluje do /Applications a spustí
```

### Oprávnění
Aby se vybraná položka rovnou **vložila** (simulace ⌘V), je potřeba povolit aplikaci
v *Nastavení systému → Soukromí a zabezpečení → Zpřístupnění*. Bez toho se položka
jen zkopíruje do schránky a vložíš ji sám přes ⌘V.

> Aplikace je podepsaná ad-hoc, takže po každém novém sestavení může být nutné
> oprávnění v Zpřístupnění odebrat a znovu přidat.

Spouštění po přihlášení: *Nastavení systému → Obecné → Položky při přihlášení* → přidat MacClipboard.
