#!/usr/bin/env python3
"""Rolka ekipy v6: osobne polaroidy (bez podpisow) z wybranych zdjec.
Uzycie: python3 buduj_rolke.py lista.tsv KATALOG_ZDJEC KATALOG_WYJSCIA
lista.tsv (TAB, '#' = komentarz), kolumny:
  plik      nazwa pliku w KATALOG_ZDJEC (np. zmniejszone 1400 px, bez EXIF)
  kadr      'auto' albo x,y,w,h w pikselach TEGO pliku (wycinek do pokazania)
  obrot     stopnie, np. -2.5 albo 1.8 (lekki przechyl polaroidu)
  rozmyj    '-' albo lista prostokatow x,y,w,h;x,y,w,h w pikselach TEGO pliku
            (tablice rejestracyjne: subtelne rozmycie, ksztalt tablicy zostaje)
  sila      promien rozmycia w px pliku zrodlowego dla tablic (domyslnie 0 = auto ~ 0.25*wysokosc prostokata)
Kolejnosc wierszy = kolejnosc w rolce (pierwsze: zdjecie w sniegu).
Wynik: ekipa_01.webp ... (przezroczyste tlo), rolka_snippet.html, podglad.jpg (do sprawdzenia).
"""
import sys, os, math
from PIL import Image, ImageDraw, ImageFilter, ImageOps

PW, PH = 480, 600          # obszar zdjecia (2x wzgledem wyswietlania: 240x300 css px na komputerze)
B, BB = 24, 84             # ramka boczna/gorna i dolna (bez podpisu)
lista, src, dst = sys.argv[1:4]
os.makedirs(dst, exist_ok=True)
rows = []
for ln in open(lista, encoding='utf-8'):
    ln = ln.rstrip('\n')
    if not ln.strip() or ln.lstrip().startswith('#'):
        continue
    c = (ln.split('\t') + ['auto', '0', '-', '0'][len(ln.split('\t')) - 1:])[:5]
    sila = float(c[4]) if c[4].strip() not in ('', '-') else 0.0
    rows.append((c[0].strip(), c[1].strip() or 'auto', float(c[2] or 0), c[3].strip() or '-', sila))

out = []
for i, (fn, kadr, obr, rozm, sila) in enumerate(rows, 1):
    im = ImageOps.exif_transpose(Image.open(os.path.join(src, fn))).convert('RGB')
    if rozm and rozm != '-':
        for r in rozm.split(';'):
            x, y, w, h = [int(float(v)) for v in r.split(',')]
            rad = sila or max(2.0, 0.25 * h)
            pad = int(rad * 2)
            box = (max(0, x - pad), max(0, y - pad), min(im.width, x + w + pad), min(im.height, y + h + pad))
            reg = im.crop(box)
            bl = reg.filter(ImageFilter.GaussianBlur(rad))
            m = Image.new('L', reg.size, 0)
            ImageDraw.Draw(m).rectangle((x - box[0], y - box[1], x - box[0] + w, y - box[1] + h), fill=255)
            m = m.filter(ImageFilter.GaussianBlur(max(1, rad / 4)))
            reg.paste(bl, (0, 0), m)
            im.paste(reg, box[:2])
    if kadr and kadr != 'auto':
        x, y, w, h = [int(float(v)) for v in kadr.split(',')]
        im = im.crop((x, y, x + w, y + h))
    ph = ImageOps.fit(im, (PW, PH), Image.LANCZOS, centering=(0.5, 0.45))
    pol = Image.new('RGBA', (PW + 2 * B, PH + B + BB), (253, 251, 246, 255))
    pol.paste(ph, (B, B))
    # cien + obrot
    rot = pol.rotate(obr, resample=Image.BICUBIC, expand=True)
    pad = 26
    can = Image.new('RGBA', (rot.width + 2 * pad, rot.height + 2 * pad), (0, 0, 0, 0))
    sh = Image.new('RGBA', rot.size, (20, 14, 6, 0))
    sh.putalpha(rot.split()[3].point(lambda a: int(a * 0.32)))
    can.alpha_composite(sh, (pad + 4, pad + 9))
    can = can.filter(ImageFilter.GaussianBlur(8))
    can.alpha_composite(rot, (pad, pad))
    name = f'ekipa_{i:02d}.webp'
    can.save(os.path.join(dst, name), 'WEBP', quality=80, method=6)
    out.append((name, can.width, can.height))
    print(name, can.size, os.path.getsize(os.path.join(dst, name)), fn)

H = out[0][2]
snip = '\n'.join(f'<img src="assets/ekipa/{n}" width="{w}" height="{h}" alt="" loading="lazy" decoding="async" draggable="false">' for n, w, h in out)
open(os.path.join(dst, 'rolka_snippet.html'), 'w').write(snip + '\n')
# podglad: wszystkie obok siebie na kremowym tle, skala 0.5
sc = 0.5
W = int(sum(w for _, w, _ in out) * sc) + 20
pv = Image.new('RGB', (W, int(max(h for *_, h in out) * sc) + 20), (251, 247, 241))
x = 10
for n, w, h in out:
    p = Image.open(os.path.join(dst, n)).resize((int(w * sc), int(h * sc)))
    pv.paste(p, (x, 10), p); x += int(w * sc)
pv.save(os.path.join(dst, 'podglad.jpg'), quality=85)
print('razem', sum(os.path.getsize(os.path.join(dst, n)) for n, *_ in out), 'B')
