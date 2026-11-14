#!/usr/bin/env python3
"""Reszta trzeciego audytu: blog (K3, K4, W11, D3, D4) i przyklad zwrotu ulgi w FAQ.
Uzycie: python3 poprawki6.py INDEX_WE BLOG_WE WYJSCIE
"""
import os, sys

IDX, BLOG, DST = sys.argv[1:4]
os.makedirs(os.path.join(DST, 'blog'), exist_ok=True)


def rep(s, a, b, n=1):
    c = s.count(a)
    if c != n:
        raise SystemExit(f'rep: oczekiwano {n}, jest {c}: {a[:100]!r}')
    return s.replace(a, b)


s = open(IDX, encoding='utf-8').read()
s = rep(s, 'Dokładną kwotę dla każdego miesiąca znajdziesz w umowie.',
        'Na przykład przy pakiecie 350/350 Mb/s po 12 miesiącach to 389,52 zł. Dokładną kwotę dla każdego miesiąca znajdziesz w umowie.')
open(os.path.join(DST, 'index.html'), 'w', encoding='utf-8').write(s)

T26_OLD = 'Dlaczego internet zwalnia wieczorami? To nie wina dostawcy!'
T26_NEW = 'Dlaczego internet zwalnia wieczorami? Często winne jest domowe Wi-Fi'
T28_OLD = 'Nie tylko WadowiceNet cierpi na dewastacjach sieci podczas nabudowy konkurencji. Letkomyślne działania operatorów niszczą infrastrukturę UT.'
T28_NEW = 'Uszkodzenia sieci przy budowie nowych linii. Nie tylko WadowiceNet ma ten problem'

n_all = 0
for fn in sorted(os.listdir(BLOG)):
    if not fn.endswith('.html'):
        continue
    t = open(os.path.join(BLOG, fn), encoding='utf-8').read()
    # K4: kwota razem z oplata za przylaczenie
    t = t.replace('umowa 24 mies., razem 1 598,97 zł, średnio', 'umowa 24 mies., razem 1 598,97 zł plus przyłączenie 1 zł albo 49 zł, średnio')
    # K3: cena po promocji i umowa w gornym pasku
    t = t.replace('Mikołajki: światłowód 15,99 zł przez 3 mies., przyłączenie od 1 zł, do 15.12',
                  'Mikołajki: światłowód 15,99 zł/mies. przez 3 mies., potem 59 i 85 zł, umowa 24 mies., przyłączenie od 1 zł, do 15.12')
    # W11: bez linku do aplikacji demo
    t = t.replace('<a href="../aplikacja/" style="color: #D5DEEA;">Aplikacja</a><br>', '')
    t = t.replace('<a href="aplikacja/" style="color: #D5DEEA;">Aplikacja</a><br>', '')
    # D4 (tytul wpisu 26 wszedzie, gdzie jest linkowany)
    t = t.replace(T26_OLD, T26_NEW)
    t = t.replace(T28_OLD, T28_NEW)
    if fn == '26.html':
        t = rep(t, 'Dlaczego dostawca nie jest winien?', 'Co zależy od dostawcy, a co od Ciebie?')
    if fn == '28.html':
        t = rep(t, 'Dochodzi również do działań, które trudno nazwać inaczej niż wrogimi. Zdarzają się przypadki celowego odcinania lub poluzowywania elementów istniejącej infrastruktury napowietrznej, takiej jak naciągi, uchwyty czy złącza a nawet tabliczek reklamowych. Takie działania mają na celu ułatwienie sobie prac kosztem stabilności cudzej sieci, ale w praktyce są zwykłym aktem wandalizmu i prowadzą do jej stopniowej degradacji.',
                'Zdarza się też, że przy pracach na słupach odcięte albo poluzowane zostają elementy istniejącej infrastruktury, takie jak naciągi, uchwyty, złącza, a nawet tabliczki informacyjne. Niezależnie od przyczyny osłabia to cudzą sieć i prowadzi do jej stopniowego niszczenia.')
        t = rep(t, 'bez jakiejkolwiek zgody i opłat na konstrukcjach należących do poprzedników, co jest ewidentnym naruszeniem prawa.',
                'bez zgody właściciela konstrukcji i bez uzgodnień.')
        t = rep(t, 'przed letkomyślną dewastacją.', 'przed niszczeniem.')
    if t.count('Aplikacja</a>') or 'razem 1 598,97 zł, średnio' in t:
        raise SystemExit('zostalo cos w ' + fn)
    open(os.path.join(DST, 'blog', fn), 'w', encoding='utf-8').write(t)
    n_all += 1
print('blog', n_all)
