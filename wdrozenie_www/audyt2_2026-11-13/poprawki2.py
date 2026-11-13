#!/usr/bin/env python3
"""Poprawki z ponownego audytu (13.11.2026) na stronie roboczej /przyklad-mikolaj/.
Uzycie: python3 poprawki2.py WEJSCIE WYJSCIE
WEJSCIE = katalog z index.html i network/*.html (stan wgrany 13.11 po pierwszym audycie).
"""
import os, re, sys, json, unicodedata

SRC, DST = sys.argv[1], sys.argv[2]
os.makedirs(os.path.join(DST, 'network'), exist_ok=True)


def rep(s, a, b, n=1):
    c = s.count(a)
    if c != n:
        raise SystemExit(f'rep: oczekiwano {n}, jest {c}: {a[:90]!r}')
    return s.replace(a, b)


def rep_re(s, pat, b, n=1, flags=re.S):
    r, c = re.subn(pat, b, s, flags=flags)
    if c != n:
        raise SystemExit(f'rep_re: oczekiwano {n}, jest {c}: {pat[:90]!r}')
    return r


def norm(x):
    x = unicodedata.normalize('NFD', x.lower())
    return ''.join(ch for ch in x if unicodedata.category(ch) != 'Mn').replace('ł', 'l')


# ---------------------------------------------------------------- wspolne
WARM = [
    ('#F6F8FB', '#FBF7F1'),   # tla sekcji: ciepla biel
    ('#F1F4F8', '#F6EEE2'),   # komorki cen, komunikaty
    ('#E3E8EF', '#E9DFD0'),   # ramki
    ('#9AA6B5', '#6B7280'),   # ramka pol formularza: kontrast 4,8:1 zamiast 2,5:1
]
PROMO_STYLE = 'background: #0B2545; color: #F2C14E; border-bottom: 1px solid #16335C;'
LICZBY_LINIA = '4 370 przyłączonych adresów · 10 382 lokale w zasięgu · 57 miejscowości · ok. 405 km światłowodu (stan na listopad 2026)'
COUNTDOWN_JS = '''<script>
(function(){try{var el=document.getElementById('odliczanie');if(!el)return;
var n=new Date(),st=new Date(2026,10,16),en=new Date(2026,11,15,23,59,59);
if(n<st){var s=Math.ceil((st-n)/864e5);el.textContent=' · start 16.11'+(s>=1?(s===1?' (jutro)':' (za '+s+' dni)'):'');}
else if(n<=en){var d=Math.ceil((en-n)/864e5);el.textContent=' · zostało '+d+(d===1?' dzień':' dni');}
else{el.textContent=' · promocja zakończona';}
}catch(e){}})();
</script>'''


def warm(s):
    for a, b in WARM:
        s = s.replace(a, b)
    return s


def common(s, pre):
    s = warm(s)
    # dolny pasek na telefonie: bez "Awaria"
    s = rep_re(s, r'<a href="' + re.escape(pre) + r'pomoc/" style="flex: 0 0 auto; background: #FFFFFF; color: #0B2545; border: 2px solid #0B2545; padding: 10px 12px;">Awaria</a>', '')
    # stopka: baza w Przemyslu i liczby
    s = rep(s, 'ul. Królewska 57, 30-081 Kraków<br>KRS', 'siedziba: ul. Królewska 57, 30-081 Kraków<br><strong style="color: #F2C14E;">Serwerownia i baza techniczna w Przemyślu</strong><br>KRS')
    s = rep(s, '<div style="max-width: 1200px; margin: 0 auto; padding: 16px; border-top: 1px solid #16335C; font-size: 13px;">Copyright',
            '<div style="max-width: 1200px; margin: 0 auto; padding: 16px; border-top: 1px solid #16335C; font-size: 13px;"><span style="display: block; margin-bottom: 4px;">' + LICZBY_LINIA + '</span>Copyright')
    # wybor pakietu wysylany razem z numerem
    s = rep(s, 'fd.append("strona",location.pathname);', 'if(f.getAttribute("data-pakiet"))fd.append("pakiet",f.getAttribute("data-pakiet"));fd.append("strona",location.pathname);')
    return s


# ---------------------------------------------------------------- strona glowna
idx = open(os.path.join(SRC, 'index.html'), encoding='utf-8').read()
MIEJSCA = json.loads('[' + re.search(r'<script>\(function\(\)\{var M=\[(.*?)\];', idx).group(1) + ']')
assert len(MIEJSCA) == 57, len(MIEJSCA)

# elementy do podstron: mapa, panorama
i = idx.find('class="utmap"'); a = idx.rfind('<svg', 0, i); b = idx.find('</svg>', i) + 6
MAPA = idx[a:b]
SEGS = [(m.group(1), m.group(0)) for m in re.finditer(r'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \d+ 380"[^>]*aria-label="([^"]+)".*?</svg>', idx, re.S)]
assert len(SEGS) == 57
PUNKTY = {}
for m in re.finditer(r'<a href="network/([^"]+)\.html" aria-label="([^"]+)"><title>[^<]*</title>\s*<circle class="dg" cx="([\d.]+)" cy="([\d.]+)"', MAPA):
    PUNKTY[m.group(1)] = (m.group(2), float(m.group(3)), float(m.group(4)))
assert len(PUNKTY) == 55, len(PUNKTY)  # Starzawa i Ciemierzowice nie maja punktu na mapie A

s = common(idx, '')

# --- head: tytul, opis, podglad, dane firmy
OPIS = 'Internet światłowodowy w Przemyślu i powiecie przemyskim: od 15,99 zł/mies. przez 3 mies., router Wi-Fi 6 w cenie, lokalny technik. Sprawdź swój adres.'
assert len(OPIS) <= 155, len(OPIS)
URL = 'https://ultratech.net.pl/przyklad-mikolaj/'
ld = {
    '@context': 'https://schema.org', '@type': 'LocalBusiness',
    'name': 'UltraTech – internet światłowodowy Przemyśl', 'legalName': 'UT sp. z o.o.',
    'url': 'https://ultratech.net.pl/', 'logo': 'https://ultratech.net.pl/logo-UT.png',
    'image': URL + 'assets/og_ut.png', 'telephone': '+48729910600', 'email': 'bok@ultratech.net.pl',
    'description': 'Lokalny operator światłowodowy. Serwerownia i baza techniczna w Przemyślu. Sieć FTTH w Przemyślu i 56 miejscowościach powiatu przemyskiego.',
    'priceRange': 'od 15,99 zł/mies.', 'vatID': 'PL9442244353',
    'areaServed': [{'@type': 'Place', 'name': n} for n in MIEJSCA] + [{'@type': 'AdministrativeArea', 'name': 'powiat przemyski'}],
}
head_add = (
    f'<meta name="description" content="{OPIS}">\n'
    '<meta property="og:type" content="website">\n'
    '<meta property="og:locale" content="pl_PL">\n'
    '<meta property="og:site_name" content="UltraTech">\n'
    '<meta property="og:title" content="Internet światłowodowy w Przemyślu i 56 miejscowościach powiatu – UltraTech">\n'
    f'<meta property="og:description" content="{OPIS}">\n'
    f'<meta property="og:url" content="{URL}">\n'
    f'<meta property="og:image" content="{URL}assets/og_ut.png">\n'
    '<meta property="og:image:width" content="1200">\n<meta property="og:image:height" content="630">\n'
    '<meta name="twitter:card" content="summary_large_image">\n'
    '<script type="application/ld+json">' + json.dumps(ld, ensure_ascii=False) + '</script>\n'
)
s = rep(s, '<title>Internet światłowodowy Przemyśl i okolice – UltraTech</title>', '<title>Internet światłowodowy Przemyśl i powiat przemyski – UltraTech</title>')
s = rep(s, '<link rel="canonical" href="https://ultratech.net.pl/">\n', '<link rel="canonical" href="https://ultratech.net.pl/">\n' + head_add)

# --- pasek promocji: granat ze zlotym tekstem (czerwien przechodzi do ramki prezentu)
s = rep(s, '<div class="promobar" style="background: #B3122B; color: #FFFFFF;', '<div class="promobar" style="' + PROMO_STYLE)

# --- pierwszy ekran
s = rep(s, '>Światłowód w Przemyślu i 56 miejscowościach powiatu. Koniec z radiówką.</h1>', '>Internet światłowodowy w Przemyślu i 56 miejscowościach powiatu</h1>')
s = rep(s, '<p class="hero-lead" style="margin: 0; font-size: 19px; line-height: 1.5; color: #D5DEEA;">Wysyłasz',
        '<p class="hero-lead" style="margin: 0; font-size: 19px; line-height: 1.5; color: #D5DEEA;"><strong style="color: #FFFFFF;">Koniec z radiówką.</strong> Wysyłasz')
s = rep(s, '<p style="margin: 0; font-size: 17px; line-height: 1.45; font-weight: 600;">potem 59 zł',
        '<p class="cena-m" style="margin: 0; font-size: 15px; line-height: 1.4; font-weight: 600;">potem 59 zł i 85 zł · <span style="color: #F7A04B;">średnio 66,62 zł/mies.</span></p>\n'
        '        <p class="cena-d" style="margin: 0; font-size: 17px; line-height: 1.45; font-weight: 600;">potem 59 zł')
s = rep(s, 'padding: 56px 16px 24px; display: flex; flex-wrap: wrap; gap: 40px; align-items: center;',
        'padding: 24px 16px 40px; display: flex; flex-wrap: wrap; gap: 32px; align-items: center; box-sizing: border-box;')
# wybrany pakiet w formularzu
s = rep(s, '<div style="font-size: 22px; font-weight: 800; color: #0B2545;">Sprawdź, czy masz światłowód</div>',
        '<div class="form-t" style="font-size: 22px; font-weight: 800; color: #0B2545;">Sprawdź, czy masz światłowód</div>\n'
        '        <div id="wybrany-pakiet" role="status" aria-live="polite" style="display: none; background: #FFF4E2; border: 1.5px solid #F7A04B; color: #7C2D12; border-radius: 10px; padding: 8px 12px; font-size: 15px; font-weight: 700;"></div>')

CSS_ADD = '''
.cena-m{display:none}
.oferta-sum{display:none}
.lp-btn{display:inline-block;background:#C2410C;color:#fff!important;text-decoration:none;font-weight:800;font-size:17px;padding:14px 22px;border-radius:10px}
.lp-btn:hover{background:#9A3412}
.hero-snieg{display:flex;flex-direction:column}
.hero-snieg>*{width:100%}
.hero-snieg>.ut-pano{order:-1;--ph:130px}
.utmap .lbl.s{font-size:13px}
@media (max-width:640px){
.hero-snieg>.ut-pano{--ph:72px}
.hero-in{padding:12px 16px 24px!important;gap:18px!important}
.hero-col{gap:8px!important}
.h1{font-size:26px!important;line-height:1.12!important}
.price{font-size:44px!important}
.cena-m{display:block}
.cena-d{display:none}
#formularz{padding:20px!important;gap:10px!important}
#formularz .form-t{font-size:20px!important}
.oferta-sum{display:block;cursor:pointer;list-style:none;text-align:center;font-weight:800;font-size:17px;color:#0B2545;background:#FBF7F1;border:2px solid #0B2545;border-radius:10px;padding:14px;margin:0 0 8px}
.oferta-sum::-webkit-details-marker{display:none}
.utmap .lbl.s,.utmap .zz{display:none}
.utmap .lbl{font-size:30px}
.cmp td:nth-child(4){order:-1;font-size:18px}
.cmp td:nth-child(4)::before{content:"Światłowód UltraTech: ";color:#0B2545;font-weight:600;font-size:14px}
.cmp td:nth-child(3){order:0;font-size:13px;color:#4A5563;font-weight:400!important}
.cmp td:nth-child(3)::before{content:"Światłowód u dużych operatorów: ";color:#4A5563;font-weight:400;font-size:13px}
.router-box{padding:18px!important}
}
'''
s = rep(s, '.hero-snieg .ut-pano{--ph:240px}\n@media (max-width:640px){.hero-snieg .ut-pano{--ph:200px}}\n', CSS_ADD.lstrip('\n'))
# stare reguly mobilne tabeli radiowki (2 kolumny) zastapione powyzej
s = rep(s, '.cmp td:nth-child(3){order:-1;font-size:18px}\n.cmp td:nth-child(3)::before{content:"Światłowód UltraTech: ";color:#0B2545;font-weight:600;font-size:14px}\n', '')

# --- liczby: wyzej (zaraz pod paskiem zalet), kremowe tlo, dokladne dane
LICZBY = '''<!--ut:liczby2--><section aria-label="UltraTech w liczbach" style="background: #FFF4E2; border-bottom: 1px solid #F3DDBD;">
    <div style="max-width: 1100px; margin: 0 auto; padding: 32px 16px 26px; box-sizing: border-box;">
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 18px 24px; text-align: center;">
        <div><div style="font-size: 44px; line-height: 1.1; font-weight: 800; color: #C2410C;">4 370</div><div style="margin-top: 4px; font-size: 16px; font-weight: 700; color: #0B2545;">przyłączonych adresów</div></div>
        <div><div style="font-size: 44px; line-height: 1.1; font-weight: 800; color: #C2410C;">10 382</div><div style="margin-top: 4px; font-size: 16px; font-weight: 700; color: #0B2545;">lokale w zasięgu sieci</div></div>
        <div><div style="font-size: 44px; line-height: 1.1; font-weight: 800; color: #C2410C;">57</div><div style="margin-top: 4px; font-size: 16px; font-weight: 700; color: #0B2545;">miejscowości w powiecie przemyskim</div></div>
        <div><div style="font-size: 44px; line-height: 1.1; font-weight: 800; color: #C2410C;">ok. 405 km</div><div style="margin-top: 4px; font-size: 16px; font-weight: 700; color: #0B2545;">własnego kabla światłowodowego</div><div style="margin-top: 2px; font-size: 13px; color: #6B4E2E;">268 km na słupach, 126 km w ziemi, 11 km odtworzonych na słupach</div></div>
      </div>
      <p style="margin: 18px 0 0; text-align: center; font-size: 15px; font-weight: 700; color: #7C2D12;">Serwerownia i baza techniczna w Przemyślu · <span style="font-weight: 500; color: #6B4E2E;">stan na listopad 2026</span></p>
    </div>
  </section><!--/ut:liczby2-->
'''
s = rep_re(s, r'  <!--ut:liczby-->.*?<!--/ut:liczby-->\n', '')
s = rep(s, '  <section id="promocja" style=', LICZBY + '  <section id="promocja" style=')

# --- karty pakietow: zapamietanie wyboru
for p in ('350 / 350', '500 / 500', '800 / 800'):
    k = s.find(f'>{p} Mb/s</h3>')
    j = s.find('<a href="#formularz" style="margin-top: auto;', k)
    assert k > 0 and j > 0
    s = s[:j] + f'<a href="#formularz" data-pakiet="{p.replace(" ", "")} Mb/s" style="margin-top: auto;' + s[j + len('<a href="#formularz" style="margin-top: auto;'):]

# --- "Co jest w cenie" zamiast szarej ramki z przylaczeniem
W_CENIE = '''<div style="margin: 20px auto 0; max-width: 900px; background: #FFF4E2; border: 1.5px solid #F3DDBD; border-radius: 16px; padding: 20px; box-sizing: border-box;">
      <div style="text-align: center; font-size: 20px; font-weight: 800; color: #0B2545; margin-bottom: 12px;">Co jest w cenie abonamentu</div>
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)); gap: 10px; text-align: center;">
        <div style="background: #FFFFFF; border-radius: 12px; padding: 12px 8px;"><div style="font-size: 26px; font-weight: 800; color: #1F7A4D;">0 zł</div><div style="font-size: 14px; font-weight: 700; color: #0B2545;">dopłaty za dom jednorodzinny</div></div>
        <div style="background: #FFFFFF; border-radius: 12px; padding: 12px 8px;"><div style="font-size: 26px; font-weight: 800; color: #1F7A4D;">0 zł</div><div style="font-size: 14px; font-weight: 700; color: #0B2545;">za router Wi-Fi 6</div></div>
        <div style="background: #FFFFFF; border-radius: 12px; padding: 12px 8px;"><div style="font-size: 26px; font-weight: 800; color: #1F7A4D;">0 zł</div><div style="font-size: 14px; font-weight: 700; color: #0B2545;">za utrzymanie linii</div></div>
        <div style="background: #FFFFFF; border-radius: 12px; padding: 12px 8px;"><div style="font-size: 26px; font-weight: 800; color: #C2410C;">od 1 zł</div><div style="font-size: 14px; font-weight: 700; color: #0B2545;">przyłączenie (masz przyłącze UT), nowe 49 zł</div></div>
      </div>
      <p style="margin: 12px 0 0; text-align: center; font-size: 13px; line-height: 1.5; color: #6B4E2E;">U części operatorów ogólnopolskich dopłata za dom jednorodzinny i router to razem do 25 zł miesięcznie (cenniki odczytane 13.11.2026).</p>
    </div>'''
s = rep(s, '<div style="margin: 16px auto 0; max-width: 680px; text-align: center; font-size: 15px; font-weight: 700; color: #0B2545; background: #FBF7F1; border-radius: 10px; padding: 10px 12px;">Przyłączenie 1 zł (masz przyłącze UT) / nowe 49 zł</div>', W_CENIE)

# --- router: ciemne tlo, wiekszy, bursztynowa poswiata
s = rep(s, '<div id="router" style="margin-top: 24px; background: #FFFFFF; border: 1.5px solid #E9DFD0; border-radius: 16px; padding: 24px; display: flex; flex-wrap: wrap; gap: 16px 24px; align-items: flex-start;">',
        '<div id="router" class="router-box" style="margin-top: 24px; background: radial-gradient(circle at 18% 50%, #1F4A85 0, #0B2545 60%); color: #FFFFFF; border-radius: 16px; padding: 28px; display: flex; flex-wrap: wrap; gap: 20px 32px; align-items: center;">')
s = rep(s, '<div style="flex: 0 1 260px; min-width: 0;"><img src="assets/router_ut.jpg" width="260" height="260" loading="lazy" alt="Router Wi-Fi 6 w cenie abonamentu" style="display: block; width: 100%; max-width: 260px; height: auto; border-radius: 12px; margin: 0 auto;"></div>',
        '<div style="flex: 0 1 340px; min-width: 0;"><img src="assets/router_ut.jpg" width="340" height="340" loading="lazy" alt="Router Wi-Fi 6 z logo UltraTech w cenie abonamentu" style="display: block; width: 100%; max-width: 340px; height: auto; border-radius: 16px; margin: 0 auto; box-shadow: 0 0 0 6px rgba(247,160,75,.35), 0 0 60px 10px rgba(247,160,75,.45);"></div>')
k = s.find('id="router"'); e = s.find('</div>\n    </div>\n', k)
blk = s[k:e]
blk2 = blk.replace('color: #0B2545;">Co dostajesz w pakiecie', 'color: #F2C14E;">Router Wi-Fi 6 w cenie: co dostajesz') \
          .replace('<span style="font-size: 13px; color: #4A5563;">', '<span style="font-size: 13px; color: #C9D6E8;">') \
          .replace('<p style="margin: 10px 0 0; font-size: 13px; color: #4A5563;">', '<p style="margin: 10px 0 0; font-size: 13px; color: #C9D6E8;">')
assert blk2 != blk and 'Router Wi-Fi 6 w cenie: co dostajesz' in blk2
s = s[:k] + blk2 + s[e:]

# --- prezent Mesh: czerwono-zlota ramka
s = rep_re(s, r'<div style="margin-top: 24px; background: #E9EEF5;.*?</a></div></div>\n    </div>',
           '''<div style="margin-top: 24px; background: linear-gradient(135deg, #B3122B, #8E0E22); color: #FFFFFF; border: 2px solid #F2C14E; border-radius: 16px; padding: 22px 24px; display: flex; flex-wrap: wrap; gap: 14px 24px; align-items: center;">
      <svg width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="#F2C14E" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="flex: none;"><rect x="3" y="8" width="18" height="4" rx="1"/><path d="M12 8v13M19 12v7a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-7M7.5 8a2.5 2.5 0 0 1 0-5C11 3 12 8 12 8s1-5 4.5-5a2.5 2.5 0 0 1 0 5"/></svg>
      <div style="flex: 1 1 280px; min-width: 0;"><div style="font-size: 15px; font-weight: 800; letter-spacing: .5px; color: #F2C14E;">PREZENT NA MIKOŁAJKI</div>
      <div style="font-size: 22px; font-weight: 800; margin-top: 2px;">Punkty Mesh do Wi-Fi w całym domu</div>
      <div style="font-size: 14px; color: #FBE3E6; margin-top: 6px;">Potem 1 punkt +19 zł, 2 punkty +25 zł, 3 punkty +35 zł miesięcznie. Dodatkowe punkty Wi-Fi z obsługą technika. <a href="#home-mesh" style="color: #F2C14E; font-weight: 700;">Co zawiera Home Mesh</a></div></div>
      <div style="flex: 0 0 auto; text-align: center; background: #F2C14E; color: #7A0A1B; border-radius: 14px; padding: 10px 18px;"><div style="font-size: 36px; line-height: 1; font-weight: 800;">0 zł</div><div style="font-size: 14px; font-weight: 800;">przez 3 miesiące</div></div>
    </div>''')

# --- pelna oferta: na telefonie zwinieta
k = s.find('<!--ut:oferta1116--><section id="oferta"')
h = s.find('<h3 style="margin: 0 0 14px; font-size: 24px; font-weight: 800; color: #0B2545;">Internet światłowodowy</h3>', k)
e = s.find('\n    </div>\n  </section>', h)
assert k > 0 and h > k and e > h
s = s[:h] + '<details class="oferta-det" open><summary class="oferta-sum">Pokaż pełny cennik, telewizję i telefon</summary>\n      ' + s[h:e] + '\n      </details>' + s[e:]

# --- tabela: trzecia kolumna "swiatlowod u duzych operatorow" + dopłaty
s = rep(s, '<th style="text-align: left; padding: 14px; border-bottom: 2px solid #E9DFD0; color: #4A5563;">Internet radiowy</th>',
        '<th style="text-align: left; padding: 14px; border-bottom: 2px solid #E9DFD0; color: #4A5563;">Internet radiowy</th>\n          <th style="text-align: left; padding: 14px; border-bottom: 2px solid #E9DFD0; color: #4A5563;">Światłowód ok. 300 Mb/s u dużych operatorów</th>')
s = rep(s, 'min-width: 520px;', 'min-width: 680px;')
s = rep(s, '>Radiówka czy światłowód?</h2>', '>Radiówka, duży operator czy UltraTech?</h2>')
OTH = {
    'Wysyłanie (upload)': 'zwykle 50–100 Mb/s',
    'Deszcz, mgła, burza': 'pogoda nie wpływa',
    'Wieczorem, gdy wszyscy w sieci': 'zależnie od sieci',
    'Opóźnienie w grach i rozmowach': 'niskie',
    'Na dachu': 'nic',
}
for row, val in OTH.items():
    pat = r'(<tr><td style="padding: 14px;[^"]*font-weight: 700;">' + re.escape(row) + r'</td><td style="(padding: 14px;[^"]*)">[^<]*</td>)'
    s = rep_re(s, pat, lambda m, v=val: m.group(1) + f'<td style="{m.group(2)}">{v}</td>')
TD = 'padding: 14px; border-bottom: 1px solid #E9DFD0;'
DOP = (f'<tr><td style="{TD} font-weight: 700;">Dopłata za dom jednorodzinny</td><td style="{TD}">zależnie od operatora</td><td style="{TD}">u części do 20 zł/mies.</td><td style="{TD} font-weight: 700; color: #1F7A4D;">0 zł</td></tr>\n'
       f'          <tr><td style="{TD} font-weight: 700;">Router Wi-Fi</td><td style="{TD}">zależnie od operatora</td><td style="{TD}">u części ok. 5 zł/mies.</td><td style="{TD} font-weight: 700; color: #1F7A4D;">Wi-Fi 6 w cenie</td></tr>\n          ')
s = rep(s, '<tr><td style="padding: 14px; font-weight: 700;">Na dachu</td>', DOP + '<tr><td style="padding: 14px; font-weight: 700;">Na dachu</td>')
k = s.find('id="radio"'); e = s.find('</section>', k)
s = s[:e] + '  <p style="margin: 12px 0 0; font-size: 13px; color: #4A5563; text-align: center;">Duzi operatorzy: oferty ok. 300 Mb/s dla domu jednorodzinnego według cenników odczytanych 13.11.2026. Warunki u poszczególnych operatorów różnią się.</p>\n  ' + s[e:]

# --- 3 kroki: bursztynowa poswiata
k = s.find('>Światłowód w 3 krokach</h2>'); e = s.find('</section>', k)
blk = s[k:e]
blk2 = blk.replace('<div style="background: #FBF7F1; border-radius: 16px; padding: 28px;', '<div style="background: #FFF8EE; border: 1px solid #F3DDBD; box-shadow: 0 10px 28px rgba(247,160,75,.18); border-radius: 16px; padding: 28px;') \
          .replace('background: #0B2545; color: #FFFFFF; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 20px;', 'background: #C2410C; color: #FFFFFF; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 20px;')
assert blk2.count('#FFF8EE') == 3, blk2.count('#FFF8EE')
s = s[:k] + blk2 + s[e:]

# --- mapa na telefonie: male podpisy schowane, glowne wieksze; podpowiedz
s = rep(s, '<!--ut:mapa-A-v1--><div class="mapa-zasiegu">', '<!--ut:mapa-A-v1--><div class="mapa-zasiegu"><p class="fine-m" style="margin: 0 0 8px; text-align: center; font-size: 14px; color: #D5DEEA;">Na mapie główne miejscowości. Pełna lista z linkami jest pod mapą.</p>')

# --- koniec strony: wezwanie do dzialania zamiast "awarii"; link dla klientow mniejszy; usuniecie ukrytej sekcji aplikacji
CTA = '''<!--ut:cta-koniec--><section style="background: #FFF4E2;">
    <div style="max-width: 900px; margin: 0 auto; padding: 48px 16px; box-sizing: border-box; text-align: center;">
      <h2 style="margin: 0 0 10px; font-size: 32px; font-weight: 800; color: #0B2545;">Sprawdźmy, czy kabel dojdzie do Twojego domu</h2>
      <p style="margin: 0 0 20px; font-size: 17px; line-height: 1.5; color: #1B1F24;">Zostaw numer, a oddzwonimy z odpowiedzią i terminem. Promocja Mikołajowa: od 15,99 zł/mies. przez 3 mies.<span id="odliczanie2"></span></p>
      <div style="display: flex; flex-wrap: wrap; gap: 12px; justify-content: center;"><a href="#formularz" class="lp-btn">Zostaw numer</a><a href="tel:729910600" title="Zadzwoń do lokalnego technika" style="display: inline-block; background: #FFFFFF; color: #0B2545; border: 2px solid #0B2545; text-decoration: none; font-weight: 800; font-size: 17px; padding: 12px 22px; border-radius: 10px;">Zadzwoń: 729 910 600</a></div>
    </div>
  </section>
  <p style="max-width: 1200px; margin: 0 auto; padding: 18px 16px; box-sizing: border-box; text-align: center; font-size: 15px; color: #4A5563;">Masz już u nas internet? <a href="pomoc/" style="font-weight: 700;">Sprawdź łącze albo zgłoś awarię</a></p>
'''
s = rep_re(s, r'  <section id="pomoc-blok".*?</section>\n  <style>\.app-qr.*?</style>\n  <section id="aplikacja" hidden.*?</section>\n', CTA)
s = rep(s, "if(n<st){var s=Math.ceil((st-n)/864e5);el.textContent=' · start 16.11'",
        "var el2=document.getElementById('odliczanie2');if(el2&&n<st)el2.textContent=' Start 16.11.';\nif(n<st){var s=Math.ceil((st-n)/864e5);el.textContent=' · start 16.11'")

s = rep(s, 'Budujemy własną sieć w Przemyślu i 56 miejscowościach w okolicy.', 'Mamy własną sieć światłowodową w Przemyślu i 56 miejscowościach w okolicy.')

# --- JS: wybor pakietu, zwijanie oferty na telefonie
JS = '''<script>(function(){var f=document.getElementById("formularz"),w=document.getElementById("wybrany-pakiet");
Array.prototype.forEach.call(document.querySelectorAll("a[data-pakiet]"),function(a){a.addEventListener("click",function(){var p=a.getAttribute("data-pakiet");if(!f||!w)return;f.setAttribute("data-pakiet",p);w.textContent="Wybrany pakiet: "+p+" (umowa 24 mies.)";w.style.display="block";});});
var d=document.querySelector(".oferta-det");if(d&&window.matchMedia&&matchMedia("(max-width:640px)").matches){d.removeAttribute("open");}
function op(){if(d&&location.hash&&location.hash!=="#formularz"&&(location.hash==="#oferta"||d.querySelector(location.hash)))d.setAttribute("open","");}
window.addEventListener("hashchange",op);op();})();</script>
'''
s = rep(s, '<!--ut:tail-->', JS + '<!--ut:tail-->')
for bad in ('id="aplikacja"', 'Wersja testowa</span></h2>', 'ponad 4 000', 'ponad 10 000', '#B3122B; color: #FFFFFF; padding'):
    assert bad not in s, bad
open(os.path.join(DST, 'index.html'), 'w', encoding='utf-8').write(s)

# ---------------------------------------------------------------- podstrony miejscowosci
SEG_BY = {norm(n): i for i, (n, _) in enumerate(SEGS)}


def mapa_wycinek(plik, html):
    if plik not in PUNKTY:  # brak punktu na mapie: wycinek wokol pierwszego sasiada, bez podswietlenia
        for sas in re.findall(r'<a href="([^"./]+)\.html" style="background: #16335C;', html):
            if sas in PUNKTY:
                nz, x, y = PUNKTY[sas]
                break
        W, H = 620, 400
        x0 = min(max(x - W / 2, 0), 1200 - W); y0 = min(max(y - H / 2, 0), 826 - H)
        m = MAPA.replace('viewBox="0 0 1200 826"', f'viewBox="{x0:.0f} {y0:.0f} {W} {H}"')
        return m.replace('href="network/', 'href="').replace('utmA_', 'utmL_').replace('aria-labelledby="utmL_t utmL_d"', 'aria-label="Mapa sieci UltraTech w okolicy"')
    nazwa, x, y = PUNKTY[plik]
    W, H = 620, 400
    x0 = min(max(x - W / 2, 0), 1200 - W); y0 = min(max(y - H / 2, 0), 826 - H)
    m = MAPA.replace('viewBox="0 0 1200 826"', f'viewBox="{x0:.0f} {y0:.0f} {W} {H}"')
    m = m.replace('href="network/', 'href="').replace('utmA_', 'utmL_')
    m = m.replace('aria-labelledby="utmL_t utmL_d"', f'aria-label="Mapa sieci UltraTech: {nazwa} i okolica"')
    a = m.find(f'<a href="{plik}.html" aria-label=')
    e = m.find('</a>', a)
    blk = m[a:e]
    blk2 = blk.replace('class="lbl s"', 'class="lbl tu"')
    ring = f'<circle cx="{x}" cy="{y}" r="16" fill="none" stroke="#F2C14E" stroke-width="3"/><circle class="hub" cx="{x}" cy="{y}" r="14" fill="none" stroke="#F7A04B" stroke-width="2"/>'
    m = m[:a] + blk2 + ring + m[e:]
    m = m.replace('.utmap .lbl.s{font-size:12px;', '.utmap .lbl.tu{font-size:22px;fill:#F2C14E;font-weight:800}\n.utmap .lbl.s{font-size:12px;')
    return m


def pano(nazwa):
    i = SEG_BY[norm(nazwa)]
    rng = [56, 0, 1] if nazwa == 'Przemyśl' else [(i + d) % 57 for d in (-4, -3, -2, -1, 0, 1, 2, 3, 4)]
    out = []
    for j in rng:
        svg = SEGS[j][1]
        if j == i:
            svg = svg.replace(f'fill="#FFFFFF">{SEGS[j][0]}</text>', f'fill="#F2C14E">{SEGS[j][0]}</text>', 1)
        else:
            svg = svg.replace('role="img"', 'aria-hidden="true"', 1)
        out.append(svg)
    return '\n'.join(out)


LP_CSS = '''.lp-pano{--ph:190px;overflow:hidden;background:linear-gradient(#0B2545,#12315C 55%,#1F4A85)}
.lp-pano-track{display:flex;justify-content:center;width:max-content;min-width:100%;margin:0 auto}
.lp-pano svg{display:block;flex:none;height:var(--ph);overflow:visible}
.lp-mapa svg{display:block;width:100%;height:auto;border-radius:16px;overflow:hidden}
.utmap .lbl.s{font-size:13px}
.cena-m{display:none}.fine-m{display:none}
.lp-btn{display:inline-block;background:#C2410C;color:#fff!important;text-decoration:none;font-weight:800;font-size:17px;padding:14px 22px;border-radius:10px}
.lp-btn:hover{background:#9A3412}
@media (max-width:640px){
.lp-pano{--ph:120px}
.lp-pano-track{justify-content:flex-start;transform:translateX(calc(50vw - 50%))}
.cena-d{display:none}.cena-m{display:block}.fine-d{display:none}.fine-m{display:block}
.lp-hero{padding:20px 16px 28px!important;gap:20px!important}
.lp-hero>div:first-child{gap:10px!important}
.lp-lead,.lp-tag{display:none!important}
.h1{font-size:28px!important}
.price{font-size:44px!important}
#formularz{padding:20px!important;gap:10px!important}
#formularz>div:first-child{font-size:19px!important}
.utmap .lbl.s{font-size:18px}
.utmap .lbl.tu{font-size:28px}
}
'''

zm = 0
for fn in sorted(os.listdir(os.path.join(SRC, 'network'))):
    if not fn.endswith('.html'):
        continue
    plik = fn[:-5]
    s = open(os.path.join(SRC, 'network', fn), encoding='utf-8').read()
    nazwa = re.search(r'<title>Internet światłowodowy (.+?) – UltraTech</title>', s).group(1)
    loc = re.search(r'<h1 class="h1"[^>]*>Internet światłowodowy (.+?)</h1>', s).group(1)  # np. "w Kaszycach"
    s = common(s, '../')
    s = rep(s, '</style>\n<script type="application/ld+json">', LP_CSS + '</style>\n<script type="application/ld+json">')
    s = s.replace('Router Wi-Fi w cenie', 'Router Wi-Fi 6 w cenie').replace('router Wi-Fi w cenie', 'router Wi-Fi 6 w cenie')
    # pasek promocji z odliczaniem, granat ze zlotem
    s = rep_re(s, r'<div style="background: #B3122B; color: #FFFFFF;([^"]*)">\s*(Mikołajki [^:]+): światłowód 15,99 zł przez 3 mies\., przyłączenie od 1 zł, do 15\.12\s*</div>',
               lambda m: f'<div style="{PROMO_STYLE}{m.group(1)}">\n    {m.group(2)}: światłowód 15,99 zł przez 3 mies., przyłączenie od 1 zł<span id="odliczanie"></span>\n  </div>')
    # spojny komunikat o zasiegu
    s = rep_re(s, r'>ŚWIATŁOWÓD DOSTĘPNY ([^<]+)</div>', lambda m: f'>SIEĆ ŚWIATŁOWODOWA ULTRATECH {m.group(1)}</div>')
    s = rep(s, '<div style="align-self: flex-start; background: #1F7A4D;', '<div class="lp-tag" style="align-self: flex-start; background: #1F7A4D;')
    s = rep_re(s, r'(\S+) budujemy własną sieć: kabel wchodzi do domu, bez anteny na dachu i bez zależności od pogody\.',
               lambda m: f'{m.group(1)} mamy własną sieć światłowodową: kabel wchodzi do domu, bez anteny na dachu i bez zależności od pogody. Wpisz adres w formularzu, a sprawdzimy, czy przyłącze jest już przy Twoim domu.')
    # podpowiedz adresu
    if plik != 'Przemysl':
        s = rep(s, 'placeholder="np. ul. Przemyska 10"', f'placeholder="np. {nazwa} 25"')
    # pierwszy ekran na telefonie: krotszy opis ceny, drobny druk pod formularzem
    s = rep(s, 'padding: 48px 16px 56px; display: flex; flex-wrap: wrap; gap: 40px; align-items: center;', 'padding: 40px 16px 48px; display: flex; flex-wrap: wrap; gap: 40px; align-items: center;')
    s = rep(s, '<div style="max-width: 1200px; margin: 0 auto; padding: 40px 16px 48px;', '<div class="lp-hero" style="max-width: 1200px; margin: 0 auto; padding: 40px 16px 48px;')
    s = rep(s, '<p style="margin: 0; font-size: 19px; line-height: 1.5; color: #D5DEEA;">Lokalna sieć', '<p class="lp-lead" style="margin: 0; font-size: 19px; line-height: 1.5; color: #D5DEEA;">Lokalna sieć')
    s = rep(s, '<p style="margin: 0; font-size: 17px; line-height: 1.4; font-weight: 600;">przez pierwsze 3 miesiące',
            '<p class="cena-m" style="margin: 0; font-size: 15px; line-height: 1.4; font-weight: 600;">przez 3 mies., potem 59 zł i 85 zł · <span style="color: #F7A04B;">średnio 66,62 zł/mies.</span></p>\n'
            '        <p class="cena-d" style="margin: 0; font-size: 17px; line-height: 1.4; font-weight: 600;">przez pierwsze 3 miesiące')
    m = re.search(r'\n        <p style="margin: 0; font-size: 14px; line-height: 1\.5; color: #D5DEEA;">(350/350 Mb/s, umowa 24 mies\..*?)</p>', s, re.S)
    fine = m.group(1)
    s = s[:m.start()] + '\n        <p class="fine-d" style="margin: 0; font-size: 14px; line-height: 1.5; color: #D5DEEA;">' + fine + '</p>' + s[m.end():]
    s = rep(s, '      </form>\n    </div>\n  </section>',
            '      </form>\n      <p class="fine-m" style="margin: 0; font-size: 13px; line-height: 1.5; color: #D5DEEA;">' + fine + '</p>\n    </div>\n  </section>')
    # pasek zalet 3 + 3 zamiast 4 + 2
    s = rep(s, 'box-sizing:border-box;display:flex;flex-wrap:wrap;gap:12px 28px;justify-content:space-between;font-size:15px;',
            'box-sizing:border-box;display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px 28px;font-size:15px;')
    # "Warto przeczytac" pod pytania
    m = re.search(r'\n    <div style="flex: 1 1 360px; min-width: 0; background: #FFFFFF; border-radius: 16px; padding: 24px;">\s*<h3[^>]*>Warto przeczytać</h3>.*?</ul>\n    </div>', s, re.S)
    blog = m.group(0)
    s = s[:m.start()] + s[m.end():]
    s = rep(s, '<div style="flex: 1 1 520px; min-width: 0;">\n      <h2 style="margin: 0 0 14px; font-size: 32px;', '<div style="flex: 1 1 520px; min-width: 0; max-width: 860px;">\n      <h2 style="margin: 0 0 14px; font-size: 32px;')
    blog_sec = ('\n  <section style="max-width: 860px; margin: 0 auto; padding: 0 16px 56px; box-sizing: border-box;">' +
                blog.replace('flex: 1 1 360px; min-width: 0; ', '') + '\n  </section>\n')
    k = s.find('<h2 style="margin: 0 0 20px; font-size: 32px; font-weight: 800; color: #0B2545;">Pytania o internet')
    e = s.find('</section>\n', k) + len('</section>\n')
    s = s[:e] + blog_sec + s[e:]
    # mapa i panorama miejscowosci
    sekcja = f'''
  <!--ut:lp-mapa--><section style="background: #0B2545; color: #FFFFFF;">
    <div style="max-width: 1200px; margin: 0 auto; padding: 48px 16px 24px; box-sizing: border-box;">
      <h2 style="margin: 0 0 8px; font-size: 32px; font-weight: 800; text-align: center;">Sieć UltraTech {loc} i okolicy</h2>
      <p style="margin: 0 auto 24px; max-width: 720px; text-align: center; font-size: 16px; line-height: 1.5; color: #D5DEEA;">Własny światłowód z serwerowni w Przemyślu do 57 miejscowości powiatu, razem ok. 405 km kabla. Kliknij miejscowość na mapie, żeby zobaczyć jej stronę.</p>
      <div class="lp-mapa" style="max-width: 900px; margin: 0 auto;">{mapa_wycinek(plik, s)}</div>
    </div>
    <div class="lp-pano" aria-label="Panorama: {nazwa} i sąsiednie miejscowości"><div class="lp-pano-track">
{pano(nazwa)}
    </div></div>
  </section><!--/ut:lp-mapa-->
'''
    k = s.find('<section style="background: #FFFFFF;">\n    <div style="max-width: 1200px; margin: 0 auto; padding: 56px 16px; box-sizing: border-box;">\n      <h2 style="margin: 0 0 20px; font-size: 32px; font-weight: 800; color: #0B2545;">Ceny internetu')
    assert k > 0, fn
    # przycisk pod cennikiem
    e = s.find('</p>\n    </div>\n  </section>', k)
    s = s[:e] + '</p>\n      <p style="margin: 20px 0 0; text-align: center;"><a href="#formularz" class="lp-btn">Sprawdź adres ' + loc + ' i zamów</a></p>' + s[e + 4:]
    s = s[:k] + sekcja.lstrip('\n') + '\n  ' + s[k:]
    # odliczanie
    s = rep(s, '<!--ut:tail-->', COUNTDOWN_JS + '\n<!--ut:tail-->')
    for bad in ('budujemy', 'DOSTĘPNY', '#B3122B', 'do 15.12\n', 'Router Wi-Fi w cenie', '>Awaria<'):
        assert bad not in s, (fn, bad)
    open(os.path.join(DST, 'network', fn), 'w', encoding='utf-8').write(s)
    zm += 1
print('index + podstron:', zm)

# ---------------------------------------------------------------- panorama: przeciaganie palcem i mysza, bez pauzy po najechaniu
PANO_JS = r'''<script>(function(){var ps=document.querySelectorAll('.ut-pano:not(.is-ready)');
var rm=window.matchMedia&&matchMedia('(prefers-reduced-motion:reduce)').matches;
Array.prototype.forEach.call(ps,function(p){p.classList.add('is-ready');var t=p.querySelector('.ut-pano-track');if(!t)return;
var n=t.children.length,i;for(i=0;i<n;i++){var c=t.children[i].cloneNode(true);c.setAttribute('aria-hidden','true');t.appendChild(c);}
p.style.overflow='hidden';p.style.touchAction='pan-y';p.style.cursor='grab';p.style.userSelect='none';p.style.webkitUserSelect='none';
var half=1,x=0,v=38,drag=false,sx=0,x0=0,last=0,moved=false,stop=false;
function size(){half=t.scrollWidth/2||1;}size();window.addEventListener('resize',size);window.addEventListener('load',size);
function draw(){x=((x%half)+half)%half;t.style.transform='translate3d('+(-x)+'px,0,0)';}
function frame(now){var dt=last?Math.min(now-last,100)/1000:0;last=now;if(!drag&&!stop&&!rm)x+=v*dt;draw();requestAnimationFrame(frame);}
requestAnimationFrame(frame);
p.addEventListener('pointerdown',function(e){if(e.pointerType==='mouse'&&e.button!==0)return;drag=true;moved=false;sx=e.clientX;x0=x;p.style.cursor='grabbing';try{p.setPointerCapture(e.pointerId);}catch(_){}});
p.addEventListener('pointermove',function(e){if(!drag)return;var d=e.clientX-sx;if(Math.abs(d)>3)moved=true;x=x0-d;draw();});
function up(){drag=false;p.style.cursor='grab';}
p.addEventListener('pointerup',up);p.addEventListener('pointercancel',up);p.addEventListener('lostpointercapture',up);
p.addEventListener('dragstart',function(e){e.preventDefault();});
p.addEventListener('click',function(e){if(moved){e.preventDefault();e.stopPropagation();return;}stop=!stop;},true);
});})();</script>'''
s = open(os.path.join(DST, 'index.html'), encoding='utf-8').read()
s = rep_re(s, r"<script>\(function\(\)\{var ps=document\.querySelectorAll\('\.ut-pano:not\(\.is-ready\)'\);.*?</script>", lambda m: PANO_JS)
s = rep(s, '@media (prefers-reduced-motion:reduce){.ut-pano{overflow-x:auto}.ut-pano.is-loop .ut-pano-track{animation:none}}', '@media (prefers-reduced-motion:reduce){.ut-pano.is-loop .ut-pano-track{animation:none}}')
open(os.path.join(DST, 'index.html'), 'w', encoding='utf-8').write(s)
print('panorama: przeciaganie OK')
