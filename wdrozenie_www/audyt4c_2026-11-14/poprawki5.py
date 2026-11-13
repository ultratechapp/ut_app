#!/usr/bin/env python3
"""Czwarty audyt (wyglad i marketing): poprawki strony roboczej.
Uzycie: python3 poprawki5.py WEJSCIE WYJSCIE [SNIPPET_ROLKI]
WEJSCIE = wynik poprawki4.py (+ naglowek "Polec nas sasiadowi").
SNIPPET_ROLKI = rolka_snippet.html z buduj_rolke.py (opcjonalnie; bez niego zostaje stara rolka).
"""
import os, re, sys

SRC, DST = sys.argv[1], sys.argv[2]
SNIP = sys.argv[3] if len(sys.argv) > 3 else None
os.makedirs(os.path.join(DST, 'network'), exist_ok=True)


def rep(s, a, b, n=1):
    c = s.count(a)
    if c != n:
        raise SystemExit(f'rep: oczekiwano {n}, jest {c}: {a[:120]!r}')
    return s.replace(a, b)


def cut(s, a, b):
    """wytnij fragment od a (wlacznie) do b (wlacznie); zwroc (s_bez, fragment)"""
    i = s.index(a); j = s.index(b, i) + len(b)
    assert s.count(a) == 1
    return s[:i] + s[j:], s[i:j]


CSS5 = '''.ek-mini{display:flex;justify-content:center;gap:4px;flex-wrap:wrap}
.ek-mini img{height:230px;width:auto}
@media (max-width:640px){.ek-mini img{height:150px}.ek-mini img:nth-child(3){display:none}}
.sticky{transition:transform .25s ease}
.sticky.ukryj{transform:translateY(130%)}
.form-odd{margin-top:-6px;text-align:center;font-size:13px;color:#4A5563}
.ut-pano:not(.ut-ekipa) text{display:none}
.ut-ekipa .ut-pano-track{gap:6px;align-items:center}
.ut-ekipa .ut-pano-track img{display:block;flex:none;height:var(--ph);width:auto;max-width:none}
.pol-kroki{list-style:none;margin:22px 0 0;padding:0;display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:14px;counter-reset:k}
.pol-kroki li{counter-increment:k;background:#FBF7F1;border-radius:14px;padding:16px 16px 16px 60px;position:relative;font-size:15px;line-height:1.45;color:#4A5563}
.pol-kroki li::before{content:counter(k);position:absolute;left:16px;top:14px;width:32px;height:32px;border-radius:999px;background:#1F7A4D;color:#fff;font-weight:800;display:flex;align-items:center;justify-content:center}
.pol-kroki strong{display:block;color:#0B2545;font-size:16px;margin-bottom:2px}
.pol-kol{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px;margin-top:18px}
.pol-kol>div{border:1.5px solid #E9DFD0;border-radius:16px;padding:20px;display:flex;flex-direction:column;gap:10px;align-items:flex-start}
.pol-kol h3{margin:0;font-size:20px;color:#0B2545}
.pol-kol p{margin:0;font-size:15px;line-height:1.5;color:#1B1F24;flex:1}
.lp-btn2{display:inline-block;background:#fff;color:#0B2545!important;border:2px solid #0B2545;text-decoration:none;font-weight:800;font-size:17px;padding:12px 20px;border-radius:10px}
.pol-zas{margin-top:16px}
.pol-zas summary{cursor:pointer;font-weight:800;color:#0B2545}
.pol-zas ol{margin:10px 0 0;padding-left:22px;font-size:15px;line-height:1.6}
.pol-linia{margin:14px 0 0;text-align:center;font-size:15px;font-weight:700;color:#14532D}
@media (max-width:640px){
.liczby-g{grid-template-columns:1fr 1fr!important;gap:14px 10px!important}
.liczby-g>div>div:first-child{font-size:30px!important}
.liczby-g>div>div:last-child{font-size:14px!important}
.pakiety-g>div:nth-child(2){order:-1}
.tylko-pc{display:none!important}
.pano-txt{display:none}
.pano-btn{padding:6px 9px!important}
}
'''

STICKY_JS = '''<script>(function(){var s=document.querySelector(".sticky"),f=document.getElementById("formularz");if(!s||!f||!("IntersectionObserver" in window))return;
new IntersectionObserver(function(e){var v=e[0].isIntersecting;s.classList.toggle("ukryj",v);s.setAttribute("aria-hidden",v?"true":"false");Array.prototype.forEach.call(s.querySelectorAll("a"),function(a){if(v)a.setAttribute("tabindex","-1");else a.removeAttribute("tabindex");});},{threshold:0}).observe(f);
Array.prototype.forEach.call(document.querySelectorAll("[data-kod]"),function(a){a.addEventListener("click",function(){var d=document.querySelector("details.kodpol");if(d)d.open=true;setTimeout(function(){var i=document.getElementById("kodpol");if(i)try{i.focus({preventScroll:true});}catch(_){i.focus();}},450);});});})();</script>
'''

ZASADY = '''<li>Polecasz jako klient UltraTech z działającą usługą internetu.</li>
            <li>Swój kod polecenia (8 znaków) i link z kodem znajdziesz w e-BOK i w aplikacji. Wysyłasz go sam, komu chcesz. Nie podajesz nam numeru sąsiada.</li>
            <li>Sąsiad podaje kod w formularzu na stronie, przez telefon albo najpóźniej przy podpisaniu umowy. Po podpisaniu umowy kodu nie da się dopisać.</li>
            <li>Sąsiad jest nowym klientem (nie korzystał z naszych usług od ponad 90 dni) i podłącza internet pod innym adresem niż Twój.</li>
            <li>Rabat dotyczy abonamentu za internet (bez telewizji, Mesh i telefonu) i jest na fakturze. Nalicza się, gdy sąsiad ma uruchomiony internet i opłaci pierwszą fakturę.</li>
            <li>Nagrodę polecającego dostajesz za maksymalnie 6 osób w roku i wtedy, gdy nie masz zaległości. Rabatu nie wymieniamy na gotówkę. Program łączy się z Promocją Mikołajową.</li>'''


def polec(pre, krotka=False):
    kroki = '' if krotka else '''
        <ol class="pol-kroki">
          <li><strong>Klient wysyła kod</strong>Kod (8 znaków) i link z kodem są w e-BOK. Wysyła go sam, komu chce.</li>
          <li><strong>Sąsiad podaje kod</strong>W formularzu, przez telefon albo najpóźniej przy podpisaniu umowy.</li>
          <li><strong>Oboje płacicie 1 zł</strong>Za jeden miesiąc internetu, gdy sąsiad opłaci pierwszą fakturę.</li>
        </ol>'''
    return f'''<!--ut:polecenia--><section id="polec" aria-labelledby="polec-t" style="background: #FFFFFF; border-top: 1px solid #E9DFD0;">
    <div style="max-width: 1100px; margin: 0 auto; padding: 56px 16px; box-sizing: border-box;">
        <div style="display: inline-block; background: #E6F4EC; color: #14532D; font-size: 13px; font-weight: 800; padding: 5px 12px; border-radius: 999px;">PROGRAM „POLEĆ SĄSIADA”</div>
        <h2 id="polec-t" style="margin: 12px 0 10px; font-size: 34px; line-height: 1.15; font-weight: 800; color: #0B2545;">Poleć nas sąsiadowi. Oboje macie miesiąc za&nbsp;1&nbsp;zł.</h2>
        <p style="margin: 0; max-width: 760px; font-size: 17px; line-height: 1.5; color: #1B1F24;">Sąsiad płaci 1 zł za 4. miesiąc umowy, a polecający 1 zł za internet w miesiącu po tym, jak sąsiad opłaci pierwszą fakturę. Przy pakiecie 350/350 Mb/s w Promocji Mikołajowej to 58 zł mniej (1 zł zamiast 59 zł).</p>{kroki}
        <div class="pol-kol">
          <div><h3>Masz kod od sąsiada?</h3><p>Wpisz go w formularzu razem z adresem. Czwarty miesiąc internetu zapłacisz 1 zł.</p><a href="#formularz" class="lp-btn" data-kod>Mam kod, sprawdź mój adres</a></div>
          <div><h3>Jesteś już klientem?</h3><p>Swój kod i link do wysłania znajdziesz w e-BOK. Rabat sąsiada nie zależy od tego, ile osób poleciłeś.</p><a href="https://ebok.ultratech.net.pl" class="lp-btn2">Jestem klientem, pokaż mój kod</a></div>
        </div>
        <details class="pol-zas"><summary>Zasady w skrócie</summary>
          <ol>
            {ZASADY}
          </ol>
          <p style="margin: 10px 0 0; font-size: 15px;"><a href="{pre}regulamin_polecen.html" style="font-weight: 800;">Regulamin programu „Poleć sąsiada”</a></p>
        </details>
    </div>
  </section><!--/ut:polecenia-->
'''


def common(s, pre):
    i = s.find('</style>\n'); s = s[:i] + CSS5 + s[i:]
    # A4: przycisk formularza = naglowek formularza, dopisek o oddzwonieniu
    s = rep(s, '>Zadzwońcie do mnie</button>', '>Sprawdźcie mój adres</button><div class="form-odd">Oddzwonimy w dni robocze z numeru 729 910 600.</div>')
    # C7: krotszy pasek kodu
    s = rep(s, 'Masz kod polecenia <strong></strong>. Gdy kod jest ważny, czwarty miesiąc internetu masz za 1 zł po opłaceniu pierwszej faktury. ',
            'Masz kod <strong></strong>: 4. miesiąc za 1 zł. ')
    # C2: na telefonie polecany pakiet pierwszy
    s = s.replace('<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(290px, 1fr)); gap: 24px; align-items: stretch;">',
                  '<div class="pakiety-g" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(290px, 1fr)); gap: 24px; align-items: stretch;">')
    # C4: bez powtorzen routera w kartach (jest w podtytule sekcji i w ramce "co w cenie")
    s = s.replace('          <li>Router Wi-Fi 6 w cenie</li>\n', '')
    # A1: dolny pasek chowa sie, gdy formularz jest na ekranie
    i = s.rfind('</body>'); s = s[:i] + STICKY_JS + s[i:]
    return s


# ---------------- strona glowna ----------------
s = open(os.path.join(SRC, 'index.html'), encoding='utf-8').read()
s = common(s, '')
s = rep(s, ' Oddzwonimy w dni robocze z numeru 729 910 600.\n', '\n')
# C6: twarde spacje w naglowku
s = rep(s, '>Internet światłowodowy w Przemyślu i 56 miejscowościach powiatu</h1>', '>Internet światłowodowy w&nbsp;Przemyślu i&nbsp;56 miejscowościach powiatu</h1>')
# B5: liczby 2x2 na telefonie
s = rep(s, '<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 18px 24px; text-align: center;">',
        '<div class="liczby-g" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 18px 24px; text-align: center;">')
# B4: przycisk pauzy - na telefonie sama ikona
s = rep(s, "bt.textContent=stop?'▶ Uruchom':'❚❚ Zatrzymaj';",
        "bt.innerHTML=stop?'<span aria-hidden=\"true\">▶</span><span class=\"pano-txt\"> Uruchom</span>':'<span aria-hidden=\"true\">❚❚</span><span class=\"pano-txt\"> Zatrzymaj</span>';bt.setAttribute('aria-label',stop?'Uruchom przesuwanie':'Zatrzymaj przesuwanie');")
# B6: Mesh w jednym zdaniu, wyliczenie pod linkiem
s = rep(s, '<div style="font-size: 14px; color: #FBE3E6; margin-top: 6px;">Usługa trwa tyle co umowa (24 mies.). Od 4. miesiąca 1 punkt 19 zł, 2 punkty 25 zł, 3 punkty 35 zł miesięcznie, czyli razem 399 zł, 525 zł albo 735 zł za 21 miesięcy. Dodatkowe punkty Wi-Fi z obsługą technika. <a href="#home-mesh" style="color: #F2C14E; font-weight: 700;">Co zawiera Home Mesh</a></div>',
        '<div style="font-size: 15px; color: #FBE3E6; margin-top: 6px;">0 zł przez 3 mies., potem od 19 zł/mies. do końca umowy (24 mies.).</div>'
        '<details class="mesh-det" style="margin-top: 6px; font-size: 14px; color: #FBE3E6;"><summary style="cursor: pointer; color: #F2C14E; font-weight: 700;">Ile to kosztuje razem i co zawiera</summary>'
        '<p style="margin: 6px 0 0;">Od 4. miesiąca 1 punkt 19 zł, 2 punkty 25 zł, 3 punkty 35 zł miesięcznie, czyli razem 399 zł, 525 zł albo 735 zł za 21 miesięcy. Dodatkowe punkty Wi-Fi z obsługą technika. <a href="#home-mesh" style="color: #F2C14E; font-weight: 700;">Co zawiera Home Mesh</a></p></details>')
# C5: drugi link do cennika tylko na komputerze
s = rep(s, '<p style="margin: 20px 0 0; text-align: center; font-size: 15px;"><a href="#oferta" style="font-weight: 700;">Zobacz pełny cennik, telewizję i telefon</a></p>',
        '<p class="tylko-pc" style="margin: 20px 0 0; text-align: center; font-size: 15px;"><a href="#oferta" style="font-weight: 700;">Zobacz pełny cennik, telewizję i telefon</a></p>')
# A3: linijka o kodzie pod kartami pakietow
s = rep(s, '\n    <!--ut:ocena2-->\n', '\n    <p class="pol-linia">Masz kod od sąsiada? 4. miesiąc internetu za 1 zł. <a href="#polec" style="color: #14532D;">Jak to działa</a></p>\n    <!--ut:ocena2-->\n')

# B2: rolka zaraz po pakietach, polecenia po "3 krokach" (nad mapa, aktualnosciami i FAQ)
s, ekipa = cut(s, '  <!--ut:ekipa-->', '</section><!--/ut:ekipa-->\n')
s, _old = cut(s, '<!--ut:polecenia-->', '<!--/ut:polecenia-->\n')
# B3: przycisk pod rolka
ekipa = rep(ekipa, '\n  </section><!--/ut:ekipa-->\n', '\n    <p style="margin: 0; padding: 0 16px 48px; text-align: center;"><a href="#formularz" class="lp-btn">Sprawdź adres</a></p>\n  </section><!--/ut:ekipa-->\n')
if SNIP:
    imgs = open(SNIP, encoding='utf-8').read().strip()
    ekipa = re.sub(r'<div class="ut-pano-track">.*?</div></div>', lambda m: '<div class="ut-pano-track">' + imgs + '</div></div>', ekipa, count=1, flags=re.S)
    s = rep(s, '.ut-ekipa{--ph:300px}', '.ut-ekipa{--ph:390px}')
    s = rep(s, '.ut-ekipa{--ph:190px!important}', '.ut-ekipa{--ph:245px!important}')
    ekipa = rep(ekipa, '--ph:300px; background: transparent; padding: 8px 0 44px;', '--ph:390px; background: transparent; padding: 8px 0 52px;')
    ekipa = rep(ekipa, 'aria-label="Zdjęcia ekipy UltraTech przy budowie i serwisie sieci"', 'role="img" aria-label="Zdjęcia ekipy UltraTech: praca na słupach, spawanie światłowodu, wykopy pod kabel i podłączenia"')
KONIEC_PROMO = '<a href="#oferta" style="font-weight: 700;">Zobacz pełny cennik, telewizję i telefon</a></p>\n  </section>\n'
s = rep(s, KONIEC_PROMO, KONIEC_PROMO + ekipa)
# B3: przycisk pod "3 krokami" + polecenia zaraz po nich
TRZY = 'zostawia wszystko podłączone i sprawdzone.</div></div>\n      </div>\n    </div>\n  </section>\n'
s = rep(s, TRZY, 'zostawia wszystko podłączone i sprawdzone.</div></div>\n      </div>\n      <p style="margin: 28px 0 0; text-align: center;"><a href="#formularz" class="lp-btn">Sprawdź adres</a></p>\n    </div>\n  </section>\n' + polec(''))
# B3: jedno haslo na przyciskach
s = rep(s, 'class="lp-btn">Zostaw numer</a>', 'class="lp-btn">Sprawdź adres</a>')
# A5: aktualnosci bez kwietniowych dat, z zajawkami
s = rep(s, '<span style="font-size: 12px; font-weight: 800; color: #4A5563;">20.04.2026</span><span style="font-size: 19px; font-weight: 800; color: #0B2545; line-height: 1.3;">Szybki internet to nie tylko światłowód. Błędy w konfiguracji Wi-Fi, które spowalniają sieć</span>',
        '<span style="font-size: 12px; font-weight: 800; color: #4A5563;">PORADNIK</span><span style="font-size: 19px; font-weight: 800; color: #0B2545; line-height: 1.3;">Szybki internet to nie tylko światłowód. Błędy w konfiguracji Wi-Fi, które spowalniają sieć</span><span style="font-size: 14px; line-height: 1.5; color: #4A5563;">Płacisz za szybki światłowód, a film się buforuje? Najczęstsze błędy w ustawieniach Wi-Fi i jak je poprawić.</span>')
s = rep(s, '<span style="font-size: 12px; font-weight: 800; color: #4A5563;">18.04.2026</span><span style="font-size: 19px; font-weight: 800; color: #0B2545; line-height: 1.3;">Telewizja z prędkością światła. Jak działa IPTV w modelu unicast na światłowodzie</span>',
        '<span style="font-size: 12px; font-weight: 800; color: #4A5563;">PORADNIK</span><span style="font-size: 19px; font-weight: 800; color: #0B2545; line-height: 1.3;">Telewizja z prędkością światła. Jak działa IPTV w modelu unicast na światłowodzie</span><span style="font-size: 14px; line-height: 1.5; color: #4A5563;">Czym telewizja przez światłowód różni się od anteny i satelity i co daje oglądanie bez opóźnień.</span>')
open(os.path.join(DST, 'index.html'), 'w', encoding='utf-8').write(s)

EK_MINI = [('01', 612, 784, 'Dwóch monterów UltraTech w śniegu przy budowie sieci'),
           ('07', 0, 0, 'Monter UltraTech przy podłączeniu w ciasnym szybie'),
           ('09', 0, 0, 'Spawanie światłowodu wieczorem')]
if SNIP:
    import re as _re
    sn = open(SNIP, encoding='utf-8').read()
    EK_MINI = [(n, *map(int, _re.search(r'ekipa_' + n + r'\.webp" width="(\d+)" height="(\d+)"', sn).groups()), a) for n, _w, _h, a in EK_MINI]
# ---------------- podstrony ----------------
for fn in sorted(os.listdir(os.path.join(SRC, 'network'))):
    if not fn.endswith('.html'):
        continue
    t = open(os.path.join(SRC, 'network', fn), encoding='utf-8').read()
    t = common(t, '../')
    # C10: bez panoramy pod mapa
    t, _p = cut(t, '    <div class="lp-pano"', '    </div></div>\n')
    assert t[t.index('<!--ut:lp-mapa-->'):].split('<!--/ut:lp-mapa-->')[0].count('lp-pano') == 0, fn
    # B3: jedno haslo
    t, n = re.subn(r'class="lp-btn">Sprawdź adres w [^<]+ i zamów</a>', 'class="lp-btn">Sprawdź adres</a>', t)
    assert n == 1, (fn, n)
    # B8: skrocona sekcja polecen przed FAQ podstrony
    k = t.index('<h2 style="margin: 0 0 20px; font-size: 32px; font-weight: 800; color: #0B2545;">Pytania o internet w')
    k = t.rindex('  <section', 0, k)
    foto = ('<section aria-label="Nasza ekipa przy pracy" style="background: #FBF7F1;"><div style="max-width: 1100px; margin: 0 auto; padding: 40px 16px 8px; box-sizing: border-box; text-align: center;">'
            '<div class="ek-mini">' + ''.join(f'<img src="../assets/ekipa/ekipa_{n}.webp" width="{w}" height="{h}" alt="{a}" loading="lazy" decoding="async">' for n, w, h, a in EK_MINI) + '</div>'
            '<p style="margin: 6px 0 0; font-size: 16px; color: #4A5563;">Sieć budujemy i serwisujemy sami, z Przemyśla. Na zdjęciach nasza ekipa przy pracy.</p></div></section>\n') if SNIP else ''
    t = t[:k] + foto + polec('../', krotka=True) + '\n' + t[k:]
    open(os.path.join(DST, 'network', fn), 'w', encoding='utf-8').write(t)

# ---------------- regulamin polecen (C8) ----------------
r = open(os.path.join(SRC, 'regulamin_polecen.html'), encoding='utf-8').read()
r = rep(r, '<a href="./">← Strona główna</a>\n',
        '<header style="display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:10px;margin-bottom:8px">'
        '<a href="./" style="display:inline-flex;align-items:center;gap:10px;text-decoration:none;color:#0B2545;font-weight:800;font-size:18px">'
        '<img src="logo-UT.png" alt="" width="36" height="36">UltraTech</a>'
        '<a href="tel:729910600" style="font-weight:800;text-decoration:none">Zadzwoń: 729 910 600</a></header>\n'
        '<a href="./">← Strona główna</a>\n')
r = rep(r, '<p style="margin:0;color:#4A5563">Wersja z 13.11.2026</p>\n',
        '<p style="margin:0;color:#4A5563">Wersja z 13.11.2026</p>\n'
        '<div class="note" style="margin-top:16px"><strong>W skrócie.</strong> Klient UltraTech wysyła sąsiadowi swój kod polecenia. '
        'Sąsiad podaje go najpóźniej przy podpisaniu umowy i płaci 1 zł za 4. miesiąc internetu. '
        'Polecający płaci 1 zł za internet w miesiącu po tym, jak sąsiad opłaci pierwszą fakturę.</div>\n')
i = r.rindex('</div>\n</body>')
r = r[:i] + ('<p style="margin-top:32px;text-align:center"><a href="./#formularz" style="display:inline-block;background:#C2410C;color:#fff;'
             'text-decoration:none;font-weight:800;font-size:17px;padding:14px 22px;border-radius:10px">Mam kod, sprawdź mój adres</a></p>\n') + r[i:]
open(os.path.join(DST, 'regulamin_polecen.html'), 'w', encoding='utf-8').write(r)
print('ok')
