"""Rysuje logo UT (pomarańczowa kula, białe litery) wektorowo i generuje ikony aplikacji.

Źródłowe logo-UT.png ma tylko 65x65 px i przezroczyste litery, więc na ciemnym tle wygląda źle.
Tu litery są białe, kula nieprzezroczysta. Geometria w ułamkach średnicy, ta sama co w lib/widgets/logo_ut.dart.
Użycie: python3 tool/logo_ut.py   (z katalogu repozytorium, wymaga Pillow)
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

GRUBOSC = 0.05
# (rodzaj, dane) w ułamkach średnicy
KRESKI = [
    ('linia', (0.205, 0.285, 0.205, 0.44)),            # U: lewa pionowa
    ('luk', (0.385, 0.44, 0.18, 90, 180)),              # U: łuk na dole (środek x,y, promień, od, do)
    ('linia', (0.385, 0.62, 0.40, 0.62)),               # U: koniec łuku
    ('linia', (0.455, 0.285, 0.455, 0.62)),             # L: pionowa
    ('linia', (0.455, 0.62, 0.52, 0.62)),               # L: stopka
    ('linia', (0.53, 0.40, 0.84, 0.40)),                # T: belka
    ('linia', (0.685, 0.465, 0.685, 0.765)),            # T: noga
]
JASNY = (247, 166, 64)
CIEMNY = (226, 92, 8)


def kula(n):
    """Kula z gradientem (jaśniej u góry po lewej) i białymi literami, RGBA n x n."""
    s = n * 4  # nadpróbkowanie
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    grad = Image.new('RGB', (s, s))
    px = grad.load()
    for y in range(s):
        for x in range(s):
            t = min(1, max(0, ((x + y) / (2 * s)) * 1.25 - 0.1))
            d = math.hypot(x - s * 0.3, y - s * 0.22) / s
            blask = max(0, 0.35 - d) * 0.9
            c = [int(JASNY[i] + (CIEMNY[i] - JASNY[i]) * t) for i in range(3)]
            c = [min(255, int(v + (255 - v) * blask)) for v in c]
            px[x, y] = tuple(c)
    maska = Image.new('L', (s, s), 0)
    ImageDraw.Draw(maska).ellipse((0, 0, s - 1, s - 1), fill=255)
    img.paste(grad, (0, 0), maska)
    d = ImageDraw.Draw(img)
    w = max(1, int(GRUBOSC * s))
    for rodzaj, v in KRESKI:
        if rodzaj == 'linia':
            x1, y1, x2, y2 = [c * s for c in v]
            d.line((x1, y1, x2, y2), fill='white', width=w)
            for (x, y) in ((x1, y1), (x2, y2)):
                d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill='white')
        else:
            cx, cy, r, a1, a2 = v
            cx, cy, r = cx * s, cy * s, r * s
            d.arc((cx - r - w / 2, cy - r - w / 2, cx + r + w / 2, cy + r + w / 2), a1, a2, fill='white', width=w)
    return img.resize((n, n), Image.LANCZOS)


def ikona(n, tlo=(255, 255, 255, 255), margines=0.08, zaokraglenie=None):
    """Kula na tle (kwadrat lub zaokrąglony kwadrat)."""
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    if tlo:
        t = Image.new('RGBA', (n, n), tlo)
        if zaokraglenie is not None:
            m = Image.new('L', (n * 4, n * 4), 0)
            ImageDraw.Draw(m).rounded_rectangle((0, 0, n * 4 - 1, n * 4 - 1), radius=int(zaokraglenie * n * 4), fill=255)
            img.paste(t, (0, 0), m.resize((n, n), Image.LANCZOS))
        else:
            img = t
    k = int(n * (1 - 2 * margines))
    img.alpha_composite(kula(k), ((n - k) // 2, (n - k) // 2))
    return img


def zapisz(img, sciezka, rgb=False):
    os.makedirs(os.path.dirname(sciezka), exist_ok=True)
    (img.convert('RGB') if rgb else img).save(sciezka)


if __name__ == '__main__':
    zapisz(kula(256), 'assets/logo.png')
    # Android: klasyczne ikony + adaptacyjne (białe tło, kula w strefie bezpiecznej)
    for nazwa, n in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        zapisz(ikona(n, margines=0.06, zaokraglenie=0.22), f'android/app/src/main/res/mipmap-{nazwa}/ic_launcher.png')
        f = int(n * 108 / 48)
        fg = Image.new('RGBA', (f, f), (0, 0, 0, 0))
        k = int(f * 0.56)
        fg.alpha_composite(kula(k), ((f - k) // 2, (f - k) // 2))
        zapisz(fg, f'android/app/src/main/res/mipmap-{nazwa}/ic_launcher_foreground.png')
    # Web (PWA)
    for n in (192, 512):
        zapisz(ikona(n, margines=0.06, zaokraglenie=0.22), f'web/icons/Icon-{n}.png')
        zapisz(ikona(n, margines=0.16), f'web/icons/Icon-maskable-{n}.png')
    zapisz(ikona(32, tlo=None, margines=0.02), 'web/favicon.png')
    # iOS: bez przezroczystości, iOS sam zaokrągla rogi
    ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    if os.path.isdir(ios):
        for plik in os.listdir(ios):
            if plik.endswith('.png'):
                n = Image.open(os.path.join(ios, plik)).size[0]
                zapisz(ikona(n, margines=0.1), os.path.join(ios, plik), rgb=True)
    # macOS
    mac = 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
    if os.path.isdir(mac):
        for plik in os.listdir(mac):
            if plik.endswith('.png'):
                n = Image.open(os.path.join(mac, plik)).size[0]
                zapisz(ikona(n, margines=0.1, zaokraglenie=0.22), os.path.join(mac, plik))
    # Windows
    win = 'windows/runner/resources/app_icon.ico'
    if os.path.exists(win):
        ikona(256, tlo=None, margines=0.02).save(win, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    # podgląd
    zapisz(ikona(512, tlo=(13, 40, 71, 255), margines=0.2), 'tool/podglad_na_granatowym.png')
