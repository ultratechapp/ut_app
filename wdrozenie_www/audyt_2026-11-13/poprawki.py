#!/usr/bin/env python3
"""Poprawki z audytu marketingowego 13.11.2026 – strona robocza przyklad-mikolaj.
Użycie: poprawki.py KATALOG_WEJ KATALOG_WYJ PANORAMA_WSTAWKA MAPA_SVG
Zmienia index.html i network/*.html; nie dotyka niczego innego."""
import re, sys, os, glob

src, dst, pano_f, map_f = sys.argv[1:5]

def rep(s, old, new, count=1, label=''):
    n = s.count(old)
    if n != count:
        raise SystemExit(f'[{label}] oczekiwano {count} wystąpień, jest {n}: {old[:90]!r}')
    return s.replace(old, new)

def rep_re(s, pat, new, count=1, label='', flags=re.S):
    r, n = re.subn(pat, new, s, flags=flags)
    if n != count:
        raise SystemExit(f'[{label}] regex: oczekiwano {count}, jest {n}: {pat[:90]!r}')
    return r

# ---------- wspólne: nagłówek (pkt 10), formularz (pkt 4, A2), skrypt ----------
HDR_OLD_RE = r'<style>\.hdr-pomoc\{.*?</style><a class="hdr-pomoc" href="([^"]*)">.*?Sprawdź łącze / Awaria</a>'
def hdr_new(m):
    href = m.group(1)
    return ('<style>.hdr-klient{color:#0B2545;font-weight:700;font-size:14px;text-decoration:underline;'
            'text-underline-offset:3px;white-space:nowrap}@media (max-width:640px){.hdr-klient{display:none}}</style>'
            f'<a class="hdr-klient" href="{href}">Dla klientów</a>')

CHK1_RE = (r'\s*<label style="display: flex; gap: 10px; align-items: flex-start; font-size: 13px; line-height: 1\.45;">\s*'
           r'<input type="checkbox"[^>]*>\s*<span>Proszę o kontakt telefoniczny w sprawie mojego zapytania[^<]*</span>\s*</label>')
MKT_OLD = 'Chcę dostawać informacje o promocjach telefonicznie, SMS-em i e-mailem (nieobowiązkowe, mogę wycofać w każdej chwili).'
MKT_NEW = 'Chcę dostawać informacje o promocjach telefonicznie i SMS-em (nieobowiązkowe, mogę wycofać w każdej chwili).'

NEW_FORM_JS = r'''<script>(function(){var B="/przyklad-mikolaj/t.php?js=1",e=encodeURIComponent;function hit(x){new Image().src=B+x+"&p="+e(location.pathname)+"&q="+e(location.search)+"&r="+e(document.referrer);}hit("");var f=document.getElementById("formularz"),b=f&&f.querySelector("button");if(b)b.addEventListener("click",function(){var t=f.querySelector("input[type=tel]"),c=f.querySelector("input.ut-mkt"),a=f.querySelector("input[type=text]"),m=f.querySelector(".ut-msg");if(!m){m=document.createElement("div");m.className="ut-msg";m.setAttribute("role","status");m.style.cssText="margin-top:12px;padding:12px 14px;border-radius:10px;font-size:14px;font-weight:600;";b.parentNode.insertBefore(m,b.nextSibling);}var ok=t&&/^\d{9}$/.test(t.value.replace(/\D/g,""));if(!ok){m.style.background="#FDE9D7";m.style.color="#7C2D12";m.textContent="Podaj 9-cyfrowy numer telefonu.";return;}b.disabled=true;m.style.background="#F1F4F8";m.style.color="#0B2545";m.textContent="Wysyłam…";var fd=new URLSearchParams();fd.append("phone",t.value.replace(/\D/g,""));fd.append("consent","1");if(a&&a.value.trim())fd.append("adres",a.value.trim().slice(0,200));var mk=c&&c.checked;fd.append("marketing",mk?"1":"0");if(mk){fd.append("marketing_tresc",c.getAttribute("data-tresc")||"");fd.append("marketing_czas",new Date().toISOString());}fd.append("strona",location.pathname);fetch("/zamowienie.php",{method:"POST",body:fd,credentials:"same-origin"}).then(function(r){return r.text()}).then(function(x){var ok=/"status"\s*:\s*"ok"/.test(x),er=(x.match(/"error"\s*:\s*"([^"]+)"/)||[])[1];if(ok){hit("&e=form");m.style.background="#E6F4EC";m.style.color="#14532D";m.textContent="Dziękujemy! Oddzwonimy w dni robocze z numeru 729 910 600.";}else{b.disabled=false;m.style.background="#FDE9D7";m.style.color="#7C2D12";m.textContent=(er||"Nie udało się wysłać zgłoszenia.")+" Możesz też zadzwonić: 729 910 600.";}}).catch(function(){b.disabled=false;m.style.background="#FDE9D7";m.style.color="#7C2D12";m.textContent="Nie udało się wysłać zgłoszenia. Zadzwoń: 729 910 600.";});});})();</script>'''

def common(s, label):
    s = rep_re(s, HDR_OLD_RE, hdr_new, label=label+':hdr')
    s = rep_re(s, CHK1_RE, '', label=label+':chk1')
    # znacznik i treść zgody marketingowej
    s = rep_re(s, r'<input type="checkbox" style="width: 20px; height: 20px; margin: 0; flex: none;">(\s*<span>)' + re.escape(MKT_OLD),
               '<input type="checkbox" class="ut-mkt" data-tresc="' + MKT_NEW + '" style="width: 20px; height: 20px; margin: 0; flex: none;">\\1' + MKT_NEW,
               label=label+':mkt')
    s = rep_re(s, r'<script>\(function\(\)\{var B="/przyklad-mikolaj/t\.php\?js=1".*?</script>', lambda m: NEW_FORM_JS, label=label+':js')
    # dolny pasek na telefonie: "Awaria" zostaje (audyt pkt 10 pozwala)
    return s

# ---------- index.html ----------
L = open(os.path.join(src, 'index.html'), encoding='utf-8').read()
L = common(L, 'index')

# A1
L = rep(L, '>NAJCZĘŚCIEJ WYBIERANY</div>', '>POLECANY</div>', label='A1')

# pkt 12: odliczanie zależne od daty startu
L = rep_re(L, r"<script>\n\(function\(\)\{try\{var el=document\.getElementById\('odliczanie'\).*?</script>",
 lambda m: """<script>
(function(){try{var el=document.getElementById('odliczanie');if(!el)return;
var n=new Date(),st=new Date(2026,10,16),en=new Date(2026,11,15,23,59,59);
if(n<st){var s=Math.ceil((st-n)/864e5);el.textContent=' · start 16.11'+(s>=1?(s===1?' (jutro)':' (za '+s+' dni)'):'');}
else if(n<=en){var d=Math.ceil((en-n)/864e5);el.textContent=' · zostało '+d+(d===1?' dzień':' dni');}
}catch(e){}})();
</script>""", label='odliczanie')

# pkt 2: śnieg w pierwszym ekranie + pkt 1: panorama wieczorna na granatowym tle
L = rep(L, '  <section style="background: #0B2545; color: #FFFFFF;">\n    <div class="hero-in"',
        '  <section class="hero-snieg" style="background: #0B2545; color: #FFFFFF; position: relative; overflow: hidden;">\n    <div class="hero-in"', label='hero-sec')
SNOW_CSS = """.hero-snieg::before{content:"";position:absolute;inset:-40px 0 0 0;pointer-events:none;opacity:.5;
background-image:radial-gradient(2px 2px at 20px 30px,#fff 50%,transparent 51%),radial-gradient(1.5px 1.5px at 90px 120px,#fff 50%,transparent 51%),radial-gradient(2.5px 2.5px at 160px 60px,#fff 50%,transparent 51%),radial-gradient(1.5px 1.5px at 230px 170px,#fff 50%,transparent 51%),radial-gradient(2px 2px at 300px 90px,#fff 50%,transparent 51%);
background-size:320px 220px;animation:ut-snieg 14s linear infinite}
.hero-snieg>*{position:relative}
@keyframes ut-snieg{from{background-position:0 0}to{background-position:40px 220px}}
@media (prefers-reduced-motion:reduce){.hero-snieg::before{animation:none}}
.oszcz{display:inline-flex;flex-direction:column;align-self:flex-start;background:#E6F4EC;color:#14532D;border-radius:10px;padding:6px 10px;font-weight:800;font-size:15px;line-height:1.3}
.oszcz small{font-weight:500;font-size:12px;color:#3F6B52}
.hero-snieg .ut-pano{--ph:240px}
@media (max-width:640px){.hero-snieg .ut-pano{--ph:200px}}
.mapa-zasiegu{max-width:960px;margin:0 auto 28px}
.mapa-zasiegu svg{display:block;width:100%;height:auto}
"""
L = rep(L, '.modal{display:none;', SNOW_CSS + '.modal{display:none;', label='css')

pano = open(pano_f, encoding='utf-8').read().strip()
pano = rep(pano, '<div class="ut-pano-cap">Jedna sieć w pierścieniu: Przemyśl i 56 miejscowości powiatu</div>\n', '', label='pano-cap')
L = rep(L, """<a href="dok/Regulamin_promocji_Mikolajowy_Swiatlowod_2026.pdf" style="color: #FFFFFF;">Regulamin promocji</a></p>
    </div>
  </section>""", """<a href="dok/Regulamin_promocji_Mikolajowy_Swiatlowod_2026.pdf" style="color: #FFFFFF;">Regulamin promocji</a></p>
    </div>
    <!--ut:panorama-wieczor-v3-->
""" + pano + """
    <!--/ut:panorama-wieczor-v3-->
  </section>""", label='pano')

L = rep(L, 'padding: 56px 16px 64px; display: flex; flex-wrap: wrap; gap: 40px;', 'padding: 56px 16px 24px; display: flex; flex-wrap: wrap; gap: 40px;', label='heropad')

# pkt 7: piąta zaleta
CHECK = '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#1F7A4D" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 6 9 17l-5-5"/></svg>'
L = rep(L, f'<div style="display: flex; gap: 10px; align-items: center;">{CHECK}0 zł za utrzymanie linii</div>',
        f'<div style="display: flex; gap: 10px; align-items: center;">{CHECK}0 zł za utrzymanie linii</div>\n      <div style="display: flex; gap: 10px; align-items: center;">{CHECK}Cena po 24 miesiącach nie rośnie</div>', label='pkt7')
L = rep(L, 'grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 16px; font-size: 15px; font-weight: 700;',
        'grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; font-size: 15px; font-weight: 700;', label='pkt7grid')

# pkt 6, 8, C8: karty pakietów
ROUTER_LI = '          <li><strong>Router Wi-Fi 6 AX3000 w cenie: 574 Mb/s w 2,4 GHz + 2402 Mb/s w 5 GHz, 4 anteny, 4 porty LAN 1 Gb/s</strong></li>\n'
L = rep(L, ROUTER_LI, '          <li>Router Wi-Fi 6 w cenie</li>\n', count=3, label='pkt8router')
for t in ['ok. 1,5 min', 'ok. 1 min', 'ok. 40 s']:
    L = rep(L, f'<li>Wysyłanie tak szybkie jak pobieranie – film 4 GB wyślesz w {t}</li>',
            f'<li><strong>Film 4 GB wyślesz w {t}</strong></li>', label='pkt8film')
for cena, kol in [('15,99', '#0B2545'), ('25,99', '#C2410C'), ('35,99', '#0B2545')]:
    L = rep(L, f'<span style="font-size: 44px; line-height: 1; font-weight: 800; color: {kol};">{cena} zł</span><span style="font-size: 16px; font-weight: 600; padding-bottom: 6px;">/mies.</span></div>',
            f'<span style="font-size: 44px; line-height: 1; font-weight: 800; color: {kol}; white-space: nowrap;">{cena} zł</span><span style="font-size: 16px; font-weight: 600; line-height: 1.25;">/mies.<br><span style="font-size: 14px; font-weight: 500; color: #4A5563;">przez 3 mies.</span></span></div>', label='C8')
for razem, kw in [('1 598,97', '441'), ('1 928,97', '351'), ('2 168,97', '351')]:
    L = rep_re(L, r'(\n        <ul style="margin: 0; padding-left: 20px; font-size: 15px; line-height: 1\.7;">\n          <li><strong>Film 4 GB(?:(?!</ul>).)*?</ul>(?:(?!razem <span class="nw">).)*?razem <span class="nw">' + re.escape(razem) + ')',
        lambda m, kw=kw: f'\n        <div class="oszcz">{kw} zł mniej niż według cennika<small>w porównaniu z cennikiem dla umowy 24 mies. od 16.11.2026</small></div>' + m.group(1), label='pkt6')
L = rep(L, '<a href="#" style="margin-top: auto;', '<a href="#formularz" style="margin-top: auto;', count=3, label='cta')

# pkt 2: baner Mesh
L = rep(L, 'Router Wi-Fi 6 w cenie. Duży dom? Dodaj punkty Mesh – 3 miesiące za 0 zł.',
        'Prezent na Mikołajki: punkty Mesh przez 3 miesiące za 0 zł.', label='mesh')

# C6: tabela radiówka
L = rep(L, 'font-weight: 700; color: #1F7A4D;">bez zmian</td>', 'font-weight: 700; color: #1F7A4D;">pogoda nie wpływa na sygnał w kablu</td>', label='C6a')
L = rep(L, 'font-weight: 700; color: #1F7A4D;">pełna prędkość pakietu</td>', 'font-weight: 700; color: #1F7A4D;">bez wieczornych spadków typowych dla radia</td>', label='C6b')

# pkt 3: miejsce na opinie (bez treści zastępczych)
L = rep(L, '  <section id="zasieg"', '''  <!--ut:opinie MIEJSCE NA OPINIE KLIENTÓW I LICZBY (audyt pkt 3): wstawić tylko prawdziwe opinie ze źródłem (np. Google)
       oraz liczby, które firma potrafi wykazać (lata działania, liczba podłączonych domów, ocena Google). Do uzupełnienia przez właściciela.-->
  <section id="zasieg"''', label='pkt3')

# pkt 9: mapa zasięgu A nad listą miejscowości (linki do podstron zostają)
mapa = open(map_f, encoding='utf-8').read()
mapa = re.sub(r'<\?xml[^>]*>\s*', '', mapa)
mapa = re.sub(r'<metadata>.*?</metadata>', '', mapa, flags=re.S)
mapa = mapa.replace(' xmlns:c2pa="http://c2pa.org/manifest"', '')
L = rep(L, 'Wybierz swoją, żeby zobaczyć ofertę i zasięg.</p>\n',
        'Wybierz swoją na mapie albo z listy, żeby zobaczyć ofertę i zasięg.</p>\n      <!--ut:mapa-A-v1--><div class="mapa-zasiegu">' + mapa.strip() +
        '</div><!--/ut:mapa-A-v1-->\n', label='pkt9')

# pkt 9: zdjęcie routera (od użytkownika, logo producenta zastąpione logo UT)
L = rep_re(L, r'<!-- TODO zdjęcie routera od UT -->\s*<div style="flex: 0 0 auto;"><svg width="72" height="72".*?</svg></div>',
  '<div style="flex: 0 1 260px; min-width: 0;"><img src="assets/router_ut.jpg" width="260" height="260" loading="lazy" alt="Router Wi-Fi 6 w cenie abonamentu" style="display: block; width: 100%; max-width: 260px; height: auto; border-radius: 12px; margin: 0 auto;"></div>', label='router-img')

# pkt 11: ukrycie sekcji aplikacji do czasu wersji ze sklepu
L = rep(L, '<section id="aplikacja" style="', '<section id="aplikacja" hidden style="display: none; ', label='pkt11')

# pkt 5: natychmiastowa odpowiedź o zasięgu
miejsc = re.findall(r'<a class="chip" href="network/[^"]+">([^<]+)</a>', L)
assert len(miejsc) == 57, len(miejsc)
L = rep(L, '<input id="adres" type="text" placeholder="np. Medyka, ul. Przemyska 10" style="font-family: inherit; font-size: 16px; padding: 14px; border: 1.5px solid #9AA6B5; border-radius: 10px; min-height: 48px; box-sizing: border-box;">',
        '<input id="adres" type="text" autocomplete="street-address" aria-describedby="zasieg-info" placeholder="np. Medyka, ul. Przemyska 10" style="font-family: inherit; font-size: 16px; padding: 14px; border: 1.5px solid #9AA6B5; border-radius: 10px; min-height: 48px; box-sizing: border-box;">\n        <div id="zasieg-info" role="status" aria-live="polite" style="display: none; font-size: 14px; font-weight: 700; line-height: 1.4; border-radius: 10px; padding: 10px 12px;"></div>', label='pkt5input')
import json
ZJS = """<script>(function(){var M=%s;function n(x){return x.toLowerCase().normalize("NFD").replace(/[\\u0300-\\u036f]/g,"").replace(/ł/g,"l");}
var N=M.map(n),i=document.getElementById("adres"),o=document.getElementById("zasieg-info"),tm;if(!i||!o)return;
function chk(){var v=n(i.value.trim());if(v.length<3){o.style.display="none";return;}
var hit=false;for(var k=0;k<N.length;k++){var re=new RegExp("(^|[^a-z])"+N[k].replace(/[.*+?^${}()|[\\]\\\\]/g,"\\\\$&")+"([^a-z]|$)");if(re.test(v)){hit=true;break;}}
o.style.display="block";if(hit){o.style.background="#E6F4EC";o.style.color="#14532D";o.textContent="Jesteśmy w Twojej miejscowości. Zostaw numer, oddzwonimy z terminem podłączenia.";}
else{o.style.background="#F1F4F8";o.style.color="#0B2545";o.textContent="Sprawdzimy, czy dojedziemy z kablem. Zostaw numer.";}}
i.addEventListener("input",function(){clearTimeout(tm);tm=setTimeout(chk,400);});i.addEventListener("blur",chk);})();</script>
""" % json.dumps(miejsc, ensure_ascii=False)
L = rep(L, '<!--ut:tail-->', ZJS + '<!--ut:tail-->', label='pkt5js')

os.makedirs(os.path.join(dst, 'network'), exist_ok=True)
open(os.path.join(dst, 'index.html'), 'w', encoding='utf-8').write(L)

# ---------- podstrony miejscowości ----------
for f in sorted(glob.glob(os.path.join(src, 'network', '*.html'))):
    s = open(f, encoding='utf-8').read()
    s = common(s, os.path.basename(f))
    open(os.path.join(dst, 'network', os.path.basename(f)), 'w', encoding='utf-8').write(s)
print('OK', len(miejsc), 'miejscowości')
