#!/usr/bin/env python3
"""Poprawki z trzeciego audytu (13.11.2026, marketing i UOKiK) + rolka ekipy.
Uzycie: python3 poprawki3.py WEJSCIE WYJSCIE   (WEJSCIE = wynik poprawki2.py)
"""
import os, re, sys, shutil

SRC, DST = sys.argv[1], sys.argv[2]
os.makedirs(os.path.join(DST, 'network'), exist_ok=True)


def rep(s, a, b, n=1):
    c = s.count(a)
    if c != n:
        raise SystemExit(f'rep: oczekiwano {n}, jest {c}: {a[:100]!r}')
    return s.replace(a, b)


def rep_re(s, pat, b, n=1, flags=re.S):
    r, c = re.subn(pat, b, s, flags=flags)
    if c != n:
        raise SystemExit(f'rep_re: oczekiwano {n}, jest {c}: {pat[:100]!r}')
    return r


PRZYL = 'plus przyłączenie 1 zł albo 49 zł'
MESH_24 = ('Usługa trwa tyle co umowa (24 mies.). Od 4. miesiąca 1 punkt 19 zł, 2 punkty 25 zł, 3 punkty 35 zł miesięcznie, '
           'czyli razem 399 zł, 525 zł albo 735 zł za 21 miesięcy.')
ZGODA_WSTEP = 'Chcę dostawać od UT sp. z o.o. informacje o promocjach (nieobowiązkowe, mogę wycofać w każdej chwili):'
ZGODA_TEL = 'Chcę dostawać od UT sp. z o.o. informacje o promocjach telefonicznie (nieobowiązkowe, mogę wycofać w każdej chwili).'
ZGODA_SMS = 'Chcę dostawać od UT sp. z o.o. informacje o promocjach SMS-em (nieobowiązkowe, mogę wycofać w każdej chwili).'
ZGODY = f'''<fieldset class="ut-zgody" style="border: 0; margin: 0; padding: 0; font-size: 13px; line-height: 1.45;">
          <legend style="padding: 0; margin: 0 0 6px;">{ZGODA_WSTEP}</legend>
          <div style="display: flex; flex-wrap: wrap; gap: 6px 22px;">
            <label style="display: inline-flex; gap: 8px; align-items: center; font-weight: 600;"><input type="checkbox" class="ut-mkt" data-kanal="telefon" data-tresc="{ZGODA_TEL}" style="width: 20px; height: 20px; margin: 0; flex: none;">telefonicznie</label>
            <label style="display: inline-flex; gap: 8px; align-items: center; font-weight: 600;"><input type="checkbox" class="ut-mkt" data-kanal="sms" data-tresc="{ZGODA_SMS}" style="width: 20px; height: 20px; margin: 0; flex: none;">SMS-em</label>
          </div>
        </fieldset>'''

COMMON_CSS = '''
/* audyt3: baner cookies na telefonie u gory, zeby nie zaslanial przycisku formularza */
@media (max-width:600px){.ck{top:0;bottom:auto!important;border-radius:0 0 12px 12px!important;box-shadow:0 6px 18px rgba(11,37,69,.25)}}
.pano-btn{position:absolute;right:10px;bottom:10px;z-index:3;display:inline-flex;align-items:center;gap:6px;background:rgba(11,37,69,.78);color:#fff;border:1.5px solid rgba(255,255,255,.55);border-radius:999px;padding:6px 12px;font:700 13px Manrope,system-ui,sans-serif;cursor:pointer}
.pano-btn:hover{background:#C2410C}
.ut-zgody legend{line-height:1.35}
@media (max-width:640px){.promobar{font-size:12px!important;line-height:1.3!important}.h1{font-size:25px!important}.hero-col .pill{display:none!important}.ut-zgody{font-size:12.5px!important}.pano-btn{padding:4px 10px;font-size:12px}}
.przed-startem{font-size:13px;font-weight:700;color:#7C2D12;background:#FFF4E2;border-radius:8px;padding:6px 10px}
'''


def common(s, pre):
    # K4 / suma
    s = s.replace('razem 1 598,97 zł', 'razem 1 598,97 zł ' + PRZYL)
    # W1: dwie zgody i nazwa firmy
    s = rep_re(s, r'<label style="display: flex; gap: 10px; align-items: flex-start; font-size: 13px; line-height: 1\.45;">\s*<input type="checkbox" class="ut-mkt"[^>]*>\s*<span>[^<]*</span>\s*</label>', ZGODY)
    s = rep(s, 'c=f.querySelector("input.ut-mkt"),', 'cs=f.querySelectorAll("input.ut-mkt:checked"),')
    s = rep(s, 'var mk=c&&c.checked;fd.append("marketing",mk?"1":"0");if(mk){fd.append("marketing_tresc",c.getAttribute("data-tresc")||"");fd.append("marketing_czas",new Date().toISOString());}',
            'var mk=cs.length>0,tr=[],kn=[];for(var j=0;j<cs.length;j++){tr.push(cs[j].getAttribute("data-tresc")||"");kn.push(cs[j].getAttribute("data-kanal")||"");}fd.append("marketing",mk?"1":"0");if(mk){fd.append("marketing_tresc",tr.join(" | "));fd.append("marketing_kanaly",kn.join(","));fd.append("marketing_czas",new Date().toISOString());}')
    # W5: licznik bez parametrow adresu (tylko utm_source/medium/campaign)
    s = rep(s, '"&q="+e(location.search)', '"&q="+e(qs())')
    s = rep(s, 'var B="/przyklad-mikolaj/t.php?js=1",e=encodeURIComponent;',
            'var B="/przyklad-mikolaj/t.php?js=1",e=encodeURIComponent;function qs(){try{var p=new URLSearchParams(location.search),o=new URLSearchParams();["utm_source","utm_medium","utm_campaign"].forEach(function(k){var v=p.get(k);if(v)o.set(k,v.slice(0,80));});var x=o.toString();return x?"?"+x:"";}catch(_){return "";}}')
    # W11: bez linku do aplikacji demo
    s = rep(s, f'<a href="{pre}aplikacja/" style="color: #D5DEEA;">Aplikacja</a><br>', '')
    # W10: "umowy w promocji od 16.11" przy formularzu przed startem
    s = rep(s, "var n=new Date(),st=new Date(2026,10,16),en=new Date(2026,11,15,23,59,59);",
            "var n=new Date(),st=new Date(2026,10,16),en=new Date(2026,11,15,23,59,59);\nif(n<st){var fb=document.querySelector('#formularz button');if(fb){var ps=document.createElement('div');ps.className='przed-startem';ps.textContent='Umowy w Promocji Mikołajowej zawieramy od 16.11.2026.';fb.parentNode.insertBefore(ps,fb.nextSibling);}}")
    i = s.find('</style>\n'); s = s[:i] + COMMON_CSS.lstrip('\n') + s[i:]
    return s


# ---------------------------------------------------------------- strona glowna
s = open(os.path.join(SRC, 'index.html'), encoding='utf-8').read()
s = common(s, '')

# K3: pelna informacja o cenie w skrotach
OPIS = 'Internet światłowodowy w Przemyślu i powiecie: 405 km własnej sieci. Od 15,99 zł/mies. przez 3 mies., potem 59 i 85 zł, umowa 24 mies. Router Wi-Fi 6 w cenie.'
s = s.replace('Internet światłowodowy w Przemyślu i powiecie przemyskim: 405 km własnej sieci, od 15,99 zł/mies. przez 3 mies., router Wi-Fi 6 w cenie. Sprawdź adres.', OPIS)
assert s.count(OPIS) == 2
s = rep(s, '"priceRange": "od 15,99 zł/mies."', '"priceRange": "15,99 zł/mies. przez 3 mies., potem 59 zł i 85 zł (umowa 24 mies.)"')
s = rep(s, 'Mikołajki: światłowód 15,99 zł przez 3 mies., przyłączenie od 1 zł<span id="odliczanie">',
        'Mikołajki: światłowód 15,99 zł/mies. przez 3 mies., potem 59 i 85 zł, umowa 24 mies., przyłączenie od 1 zł<span id="odliczanie">')
s = rep(s, 'Promocja Mikołajowa: światłowód od 15,99 zł i przyłączenie za 1 zł', 'Promocja Mikołajowa: światłowód od 15,99 zł przez 3 mies. i przyłączenie od 1 zł')
s = rep(s, 'Promocja Mikołajowa: od 15,99 zł/mies. przez 3 mies.<span id="odliczanie2">',
        'Promocja Mikołajowa: od 15,99 zł/mies. przez 3 mies., potem 59 zł i 85 zł, umowa 24 mies.<span id="odliczanie2">')
# W8: z e-faktura przy cenie
s = rep(s, '<span style="font-size: 16px; font-weight: 400; color: #D5DEEA;">przez pierwsze 3 mies.</span>',
        '<span style="font-size: 16px; font-weight: 400; color: #D5DEEA;">przez pierwsze 3 mies., z e-fakturą</span>')
s = rep(s, 'przez 3 mies.</span></span>', 'przez 3 mies., z&nbsp;e\u2011fakturą</span></span>', n=3)
# K4: karty
s = rep_re(s, r'\(razem <span class="nw">([\d  ,]+ zł)</span>\)', lambda m: f'(razem <span class="nw">{m.group(1)}</span> {PRZYL})', n=3)
# W2
s = rep(s, 'Cena po 24 miesiącach nie rośnie', 'Po 24 miesiącach płacisz tyle co w miesiącach 13–24')
# W6
s = rep(s, 'Jesteśmy w Twojej miejscowości. Zostaw numer, oddzwonimy z terminem podłączenia.', 'Mamy sieć w Twojej miejscowości. Sprawdzimy Twój adres i oddzwonimy.')
# W9
s = s.replace('wyślesz w ok. 1,5 min</strong>', 'wyślesz w ok. 1,5 min</strong> (przy prędkości maksymalnej)')
s = s.replace('wyślesz w ok. 1 min</strong>', 'wyślesz w ok. 1 min</strong> (przy prędkości maksymalnej)')
s = s.replace('wyślesz w ok. 40 s</strong>', 'wyślesz w ok. 40 s</strong> (przy prędkości maksymalnej)')
assert s.count('(przy prędkości maksymalnej)') == 3
s = rep(s, '>zwykle 2–10 Mb/s<', '>często 2–10 Mb/s<')
# K1: Mesh bez "prezentu", z czasem trwania i kosztem
s = rep(s, '>PREZENT NA MIKOŁAJKI<', '>W PROMOCJI MIKOŁAJOWEJ<')
s = rep(s, 'Potem 1 punkt +19 zł, 2 punkty +25 zł, 3 punkty +35 zł miesięcznie. Dodatkowe punkty Wi-Fi z obsługą technika. <a href="#home-mesh" style="color: #F2C14E;',
        MESH_24 + ' Dodatkowe punkty Wi-Fi z obsługą technika. <a href="#home-mesh" style="color: #F2C14E;')
s = rep(s, '<div style="font-size: 14px; font-weight: 800;">przez 3 miesiące</div>', '<div style="font-size: 14px; font-weight: 800;">przez pierwsze 3 mies.</div>')
s = rep(s, 'W promocji 3 miesiące za 0 zł. <a href="#home-mesh"', 'W promocji pierwsze 3 miesiące za 0 zł, usługa na czas umowy (24 mies.). <a href="#home-mesh"')
s = rep(s, 'W Promocji Mikołajowej pierwsze 3 miesiące za 0 zł.</p>', 'W Promocji Mikołajowej pierwsze 3 miesiące za 0 zł. ' + MESH_24 + '</p>')
s = rep(s, 'a Mesh to dodatkowe punkty: 0 zł przez 3 miesiące, potem 19 zł (1 punkt), 25 zł (2 punkty) lub 35 zł (3 punkty) miesięcznie.',
        'a Mesh to dodatkowe punkty: 0 zł przez pierwsze 3 miesiące, potem 19 zł (1 punkt), 25 zł (2 punkty) lub 35 zł (3 punkty) miesięcznie. Usługa Mesh trwa tyle co umowa (24 mies.), więc za 21 płatnych miesięcy to 399 zł, 525 zł albo 735 zł.')
assert 'PREZENT' not in s and 'Prezent' not in s
# W7: na komputerze ceny po promocji w pierwszym ekranie
s = rep(s, '.hero-snieg>.ut-pano{order:-1;--ph:130px}', '.hero-snieg>.ut-pano{order:-1;--ph:110px}\n@media (min-width:641px){.price{font-size:72px!important}.hero-col{gap:14px!important}.hero-tag{font-size:12px!important;padding:4px 10px!important}}')

# D6 + rolka ekipy: wspolny skrypt panoram z przyciskiem pauzy
s = rep(s, "var half=1,x=0,v=38,drag=false,sx=0,x0=0,last=0,moved=false,stop=false;",
        "var half=1,x=0,v=38,drag=false,sx=0,x0=0,last=0,moved=false,stop=false;\nvar bt=document.createElement('button');bt.type='button';bt.className='pano-btn';function lab(){bt.textContent=stop?'▶ Uruchom':'❚❚ Zatrzymaj';bt.setAttribute('aria-pressed',stop?'true':'false');}lab();p.appendChild(bt);\nbt.addEventListener('pointerdown',function(e){e.stopPropagation();});bt.addEventListener('click',function(e){e.stopPropagation();stop=!stop;lab();});\nArray.prototype.forEach.call(t.querySelectorAll('img'),function(im){im.addEventListener('load',size);});")
s = rep(s, "p.addEventListener('click',function(e){if(moved){e.preventDefault();e.stopPropagation();return;}stop=!stop;},true);",
        "p.addEventListener('click',function(e){if(e.target===bt)return;if(moved){e.preventDefault();e.stopPropagation();return;}stop=!stop;lab();},true);")
s = rep(s, "p.style.overflow='hidden';", "p.style.overflow='hidden';if(getComputedStyle(p).position==='static')p.style.position='relative';")
# skrypt ma dzialac dla wszystkich panoram na stronie: przenosimy go na koniec strony
m = re.search(r"<script>\(function\(\)\{var ps=document\.querySelectorAll\('\.ut-pano:not\(\.is-ready\)'\);.*?</script>", s, re.S)
pano_js = m.group(0)
s = s[:m.start()] + s[m.end():]
s = rep(s, '<!--ut:tail-->', pano_js + '\n<!--ut:tail-->')

EKIPA = '''<!--ut:ekipa--><section aria-labelledby="ekipa-t" style="background: #FBF7F1;">
    <div style="max-width: 1200px; margin: 0 auto; padding: 56px 16px 20px; box-sizing: border-box; text-align: center;">
      <h2 id="ekipa-t" style="margin: 0 0 8px; font-size: 38px; font-weight: 800; color: #0B2545; letter-spacing: -0.5px;">Nasza ekipa z Przemyśla przy pracy</h2>
      <p style="margin: 0 auto; max-width: 720px; font-size: 17px; line-height: 1.5; color: #4A5563;">Słupy, wykopy, spawanie włókien i podłączenia w domach. Tak budujemy i serwisujemy naszą sieć, w deszczu i w śniegu.</p>
    </div>
    <div class="ut-pano ut-ekipa" aria-label="Zdjęcia ekipy UltraTech przy budowie i serwisie sieci" style="--ph:300px; background: transparent; padding: 8px 0 44px;"><div class="ut-pano-track"><img src="assets/ekipa_rolka_v5.webp" width="11896" height="760" alt="Zdjęcia ekipy UltraTech: praca na słupach, wykopy pod kabel, spawanie światłowodu, podłączenia u klientów i samochody serwisowe" loading="lazy" decoding="async" draggable="false" style="display: block; flex: none; height: var(--ph); width: auto; max-width: none;"></div></div>
  </section><!--/ut:ekipa-->
'''
s = rep(s, '.hero-snieg>.ut-pano{order:-1;', '.ut-ekipa{--ph:300px}\n@media (max-width:640px){.ut-ekipa{--ph:190px!important}}\n.hero-snieg>.ut-pano{order:-1;')
k = s.find('>Światłowód w 3 krokach</h2>')
e = s.find('</section>\n', k) + len('</section>\n')
s = s[:e] + '  ' + EKIPA + s[e:]
open(os.path.join(DST, 'index.html'), 'w', encoding='utf-8').write(s)

# karty pakietow do podstron (W13)
kk = s.find('<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(290px, 1fr)); gap: 24px; align-items: stretch;">')
ke = s.find('\n    <!--ut:ocena2-->', kk)
KARTY = s[kk:ke].replace('href="dok/', 'href="../dok/')
assert KARTY.count('Chcę ten pakiet') == 3
KARTY_CSS = ('.oszcz{display:inline-flex;flex-direction:column;align-self:flex-start;background:#E6F4EC;color:#14532D;border-radius:10px;padding:6px 10px;font-weight:800;font-size:15px;line-height:1.3}\n'
             '.oszcz small{font-weight:500;font-size:12px;color:#3F6B52}\n.nw{white-space:nowrap}\n')
PAK_JS = '''<script>(function(){var f=document.getElementById("formularz"),w=document.getElementById("wybrany-pakiet");
Array.prototype.forEach.call(document.querySelectorAll("a[data-pakiet]"),function(a){a.addEventListener("click",function(){var p=a.getAttribute("data-pakiet");if(!f||!w)return;f.setAttribute("data-pakiet",p);w.textContent="Wybrany pakiet: "+p+" (umowa 24 mies.)";w.style.display="block";});});})();</script>
'''

n = 0
for fn in sorted(os.listdir(os.path.join(SRC, 'network'))):
    if not fn.endswith('.html'):
        continue
    s = open(os.path.join(SRC, 'network', fn), encoding='utf-8').read()
    s = common(s, '../')
    title = re.search(r'<title>([^<]+)</title>', s).group(1)
    desc = re.search(r'<meta name="description" content="([^"]+)">', s).group(1)
    canon = re.search(r'<link rel="canonical" href="([^"]+)">', s).group(1)
    # K3 w opisie: dopisac "umowa 24 mies." jest juz ("(umowa 24 mies.)"); sprawdzenie
    assert 'potem 59 zł i 85 zł (umowa 24 mies.)' in desc, fn
    # D7: podglad dla Facebooka
    og = (f'<meta property="og:type" content="website">\n<meta property="og:locale" content="pl_PL">\n<meta property="og:site_name" content="UltraTech">\n'
          f'<meta property="og:title" content="{title}">\n<meta property="og:description" content="{desc}">\n<meta property="og:url" content="{canon}">\n'
          '<meta property="og:image" content="https://ultratech.net.pl/przyklad-mikolaj/assets/og_ut.png">\n<meta property="og:image:width" content="1200">\n<meta property="og:image:height" content="630">\n'
          '<meta name="twitter:card" content="summary_large_image">\n')
    s = rep(s, f'<link rel="canonical" href="{canon}">\n', f'<link rel="canonical" href="{canon}">\n' + og)
    s = rep(s, '"priceRange": "od 15,99 zł/mies."', '"priceRange": "15,99 zł/mies. przez 3 mies., potem 59 zł i 85 zł (umowa 24 mies.)"')
    # K3 pasek
    s = rep_re(s, r': światłowód 15,99 zł przez 3 mies\., przyłączenie od 1 zł<span id="odliczanie">',
               ': światłowód 15,99 zł/mies. przez 3 mies., potem 59 i 85 zł, umowa 24 mies., przyłączenie od 1 zł<span id="odliczanie">')
    # W8
    s = rep(s, '>przez 3 mies., potem 59 zł i 85 zł · <span', '>przez 3 mies., z e-fakturą, potem 59 zł i 85 zł · <span')
    s = rep(s, '>przez pierwsze 3 miesiące, potem 59 zł', '>przez pierwsze 3 miesiące (z e-fakturą), potem 59 zł')
    # K1 w drobnym druku
    s = rep(s, 'Mesh (dodatkowe punkty Wi-Fi z obsługą): 0 zł przez 3 miesiące, potem 1 punkt 19 zł, 2 punkty 25 zł, 3 punkty 35 zł/mies.',
            'Mesh (dodatkowe punkty Wi-Fi z obsługą): 0 zł przez pierwsze 3 miesiące, potem 1 punkt 19 zł, 2 punkty 25 zł, 3 punkty 35 zł/mies.; usługa trwa tyle co umowa (24 mies.).')
    # K4 w tabeli
    s = rep(s, '<p style="margin: 12px 0 0; font-size: 13px; color: #4A5563;">Cena z rabatem 5 zł za e-fakturę',
            '<p style="margin: 12px 0 0; font-size: 13px; color: #4A5563;">Kwoty „razem” nie obejmują jednorazowej opłaty za przyłączenie: 1 zł (istniejące przyłącze UT) albo 49 zł (nowe). Cena z rabatem 5 zł za e-fakturę')
    # W13: karty pakietow nad tabela + wybor pakietu
    k = s.find('>Ceny internetu ')
    h2e = s.find('</h2>', k) + len('</h2>')
    s = s[:h2e] + '\n      ' + KARTY + '\n      <h3 style="margin: 32px 0 12px; font-size: 22px; font-weight: 800; color: #0B2545;">Wszystkie miesiące w tabeli</h3>' + s[h2e:]
    s = rep(s, '</style>\n<script type="application/ld+json">', KARTY_CSS + '</style>\n<script type="application/ld+json">')
    s = rep_re(s, r'(<form id="formularz"[^>]*>\s*<div style="font-size: 22px; font-weight: 800; color: #0B2545;">[^<]*</div>)',
               lambda m: m.group(1) + '\n        <div id="wybrany-pakiet" role="status" aria-live="polite" style="display: none; background: #FFF4E2; border: 1.5px solid #F7A04B; color: #7C2D12; border-radius: 10px; padding: 8px 12px; font-size: 15px; font-weight: 700;"></div>')
    s = rep(s, '<!--ut:tail-->', PAK_JS + '<!--ut:tail-->')
    for bad in ('Aplikacja</a>', 'e(location.search)'):
        assert bad not in s, (fn, bad)
    open(os.path.join(DST, 'network', fn), 'w', encoding='utf-8').write(s)
    n += 1
print('index + podstron:', n)
