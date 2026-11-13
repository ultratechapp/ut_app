# Poprawki z ponownego audytu (13.11.2026) – strona robocza /przyklad-mikolaj/

Zawartość `www/` (59 plików): `index.html`, `network/*.html` (57), `assets/og_ut.png` (nowy).
Źródło: stan wgrany 13.11 (`audyt_2026-11-13/www`), przetworzony `poprawki2.py`.

## Wgranie (tylko po zgodzie właściciela)

```bash
cd /var/www/html/przyklad-mikolaj
D=$(date +%F_%H%M)
mkdir -p /home/ut/kopie_www/przyklad-mikolaj_$D
cp -a index.html network /home/ut/kopie_www/przyklad-mikolaj_$D/
cp index.html index.html.bak_$D
# z katalogu z rozpakowaną paczką:
cp www/index.html /var/www/html/przyklad-mikolaj/index.html
cp www/network/*.html /var/www/html/przyklad-mikolaj/network/
cp www/assets/og_ut.png /var/www/html/przyklad-mikolaj/assets/og_ut.png
cd /var/www/html/przyklad-mikolaj && md5sum -c <ścieżka>/MD5SUMS
```

Przy publikacji na ultratech.net.pl: poprawić adresy `og:url`, `og:image` i `image` w danych firmy
(teraz wskazują /przyklad-mikolaj/), zdjąć `noindex`.
