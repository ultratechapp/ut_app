#!/usr/bin/env python3
"""C3 czwartego audytu: pod cena jedna linijka warunkow, reszta pod 'Szczegoly ceny'.
Uzycie: python3 poprawki7.py WE_DIR WY_DIR   (WE_DIR z index.html i network/)"""
import os, re, sys
SRC, DST = sys.argv[1:3]
OLD = re.compile(r'(<p class="fine-([dm])" style="margin: 0; font-size: (\d+)px; line-height: 1\.5; color: #D5DEEA;">)350/350 Mb/s, umowa 24 mies\., razem 1 598,97 zł plus przyłączenie 1 zł albo 49 zł, średnio 66,62 zł/mies\. (Cena z rabatem 5 zł za e-fakturę \(bez niego o 5 zł wyższa\)\. Router Wi-Fi 6 w cenie\. Przyłączenie 1 zł przy istniejącym przyłączu, nowe standardowe 49 zł\. Dla nowych klientów i byłych po ponad 90 dniach przerwy; nie dla obecnych klientów\.) (<a href="([^"]*Regulamin_promocji[^"]*)" style="color: #FFFFFF;">Regulamin(?: promocji)?</a>)</p>')
def new(m):
    cls, fs, rest, link = m.group(2), m.group(3), m.group(4), m.group(5)
    return (f'<div class="fine-{cls}" style="margin: 0; font-size: {fs}px; line-height: 1.5; color: #D5DEEA;">'
            f'<p style="margin: 0;">Pakiet 350/350 Mb/s, umowa 24 mies., razem 1 598,97 zł plus przyłączenie 1 zł albo 49 zł. Promocja tylko dla nowych klientów.</p>'
            f'<details class="cena-det"><summary style="cursor: pointer; font-weight: 700; color: #FFFFFF;">Szczegóły ceny</summary>'
            f'<p style="margin: 4px 0 0;">Średnio 66,62 zł/mies. {rest} {link}</p></details></div>')
CSS = '.cena-det summary{list-style:none}.cena-det summary::-webkit-details-marker{display:none}.cena-det summary::after{content:" ▾"}.cena-det[open] summary::after{content:" ▴"}\n'
files = ['index.html'] + ['network/' + f for f in sorted(os.listdir(os.path.join(SRC, 'network'))) if f.endswith('.html')]
os.makedirs(os.path.join(DST, 'network'), exist_ok=True)
for fn in files:
    s = open(os.path.join(SRC, fn), encoding='utf-8').read()
    s, n = OLD.subn(new, s)
    assert n == 2, (fn, n)
    i = s.find('</style>\n'); s = s[:i] + CSS + s[i:]
    open(os.path.join(DST, fn), 'w', encoding='utf-8').write(s)
print(len(files))
