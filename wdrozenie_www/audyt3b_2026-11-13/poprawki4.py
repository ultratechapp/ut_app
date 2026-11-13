#!/usr/bin/env python3
"""Program polecen "Polec sasiada" (audyt 3 + kontrakt v4) i rolka ekipy z rozmazanymi tablicami.
Uzycie: python3 poprawki4.py WEJSCIE WYJSCIE   (WEJSCIE = wynik poprawki3.py)
"""
import os, re, sys

SRC, DST = sys.argv[1], sys.argv[2]
os.makedirs(os.path.join(DST, 'network'), exist_ok=True)


def rep(s, a, b, n=1):
    c = s.count(a)
    if c != n:
        raise SystemExit(f'rep: oczekiwano {n}, jest {c}: {a[:100]!r}')
    return s.replace(a, b)


ALF = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
# odczyt ?polecam= : zapis na czas wizyty (sessionStorage), usuniecie z adresu przed licznikiem, pasek i pole w formularzu
POL_JS = '''<script>(function(){var K="ut_polecam",R=/^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$/;
function nk(x){return String(x||"").toUpperCase().replace(/[\\s-]/g,"");}
var kod=null;try{var u=new URL(location.href),q=u.searchParams.get("polecam");if(q!==null){var v=nk(q);if(R.test(v)){try{sessionStorage.setItem(K,v);}catch(_){}}u.searchParams.delete("polecam");history.replaceState(null,"",u.pathname+(u.search||"")+u.hash);}}catch(_){}
try{kod=sessionStorage.getItem(K);}catch(_){}
window.utPolecam=function(){var i=document.getElementById("kodpol"),v=nk(i&&i.value);return R.test(v)?v:"";};
function go(){var i=document.getElementById("kodpol");if(kod&&i){i.value=kod;var d=i.closest("details");if(d)d.open=true;}
if(!kod)return;var b=document.createElement("div");b.className="pol-bar";b.setAttribute("role","status");
b.innerHTML='Masz kod polecenia <strong></strong>. Gdy kod jest ważny, czwarty miesiąc internetu masz za 1 zł po opłaceniu pierwszej faktury. <a href="REG">Regulamin</a>';
b.querySelector("strong").textContent=kod;var f=document.body.firstElementChild;document.body.insertBefore(b,f?f.nextSibling:null);}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",go);else go();})();</script>
'''
POL_CSS = '''.pol-bar{background:#1F7A4D;color:#fff;padding:9px 16px;text-align:center;font:600 14px/1.4 Manrope,system-ui,sans-serif}
.pol-bar a{color:#fff;font-weight:800}
.kodpol summary{cursor:pointer;font-size:14px;font-weight:700;color:#0B2545;list-style:none}
.kodpol summary::-webkit-details-marker{display:none}
.kodpol input{margin-top:6px;width:100%;font-family:inherit;font-size:16px;letter-spacing:2px;text-transform:uppercase;padding:10px 12px;border:1.5px solid #6B7280;border-radius:10px;box-sizing:border-box}
'''
KOD_POLE = ('<details class="kodpol"><summary>+ Mam kod polecenia</summary>'
            '<label for="kodpol" style="display: block; margin-top: 6px; font-size: 13px;">Kod polecenia od klienta UltraTech (8 znaków, nieobowiązkowe)</label>'
            '<input id="kodpol" type="text" maxlength="12" autocomplete="off" autocapitalize="characters" spellcheck="false" placeholder="np. K7M4PX2Q"></details>')


def common(s, pre):
    s = s.replace('ekipa_rolka_v5.webp', 'ekipa_rolka_v5b.webp')
    i = s.find('</style>\n'); s = s[:i] + POL_CSS + s[i:]
    # skrypt polecen zaraz po <body>, przed licznikiem
    s = rep(s, '<body>\n', '<body>\n' + POL_JS.replace('REG', pre + 'regulamin_polecen.html'))
    # pole kodu pod przyciskiem formularza
    s = rep_re1(s, r'(<form id="formularz".*?<button type="button"[^>]*>[^<]*</button>)', lambda m: m.group(1) + '\n        ' + KOD_POLE)
    # wysylka kodu
    s = rep(s, 'if(f.getAttribute("data-pakiet"))', 'var kp=window.utPolecam&&window.utPolecam();if(kp)fd.append("kod_polecenia",kp);if(f.getAttribute("data-pakiet"))')
    # stopka: regulamin programu
    s = rep(s, 'Regulamin Promocji Mikołajowej</a><br>', f'Regulamin Promocji Mikołajowej</a><br><a href="{pre}regulamin_polecen.html" style="color: #D5DEEA;">Regulamin programu „Poleć sąsiada”</a><br>')
    return s


def rep_re1(s, pat, f):
    r, c = re.subn(pat, f, s, count=1, flags=re.S)
    if c != 1:
        raise SystemExit('rep_re1: ' + pat[:80])
    return r


SEKCJA = '''<!--ut:polecenia--><section id="polec" aria-labelledby="polec-t" style="background: #FFFFFF; border-top: 1px solid #E9DFD0;">
    <div style="max-width: 1100px; margin: 0 auto; padding: 56px 16px; box-sizing: border-box; display: flex; flex-wrap: wrap; gap: 28px 40px; align-items: flex-start;">
      <div style="flex: 1 1 340px; min-width: 0;">
        <div style="display: inline-block; background: #E6F4EC; color: #14532D; font-size: 13px; font-weight: 800; padding: 5px 12px; border-radius: 999px;">PROGRAM „POLEĆ SĄSIADA”</div>
        <h2 id="polec-t" style="margin: 12px 0 10px; font-size: 34px; line-height: 1.15; font-weight: 800; color: #0B2545;">Poleć sąsiada. Oboje macie miesiąc internetu za 1 zł.</h2>
        <p style="margin: 0 0 14px; font-size: 17px; line-height: 1.5; color: #1B1F24;">Sąsiad płaci 1 zł za 4. miesiąc umowy. Przy pakiecie 350/350 Mb/s w Promocji Mikołajowej to 58 zł mniej (1 zł zamiast 59 zł). Ty płacisz 1 zł za internet w miesiącu po tym, jak sąsiad opłaci pierwszą fakturę.</p>
        <p style="margin: 0 0 18px; font-size: 16px; font-weight: 700; color: #14532D;">Rabat sąsiada nie zależy od tego, ile osób poleciłeś.</p>
        <a href="regulamin_polecen.html" style="font-weight: 800;">Regulamin programu „Poleć sąsiada”</a>
      </div>
      <ol style="flex: 1 1 420px; min-width: 0; margin: 0; padding-left: 22px; font-size: 15px; line-height: 1.6; color: #1B1F24; background: #FBF7F1; border-radius: 16px; padding: 20px 20px 20px 42px; box-sizing: border-box;">
        <li style="margin-bottom: 6px;">Polecasz jako klient UltraTech z działającą usługą internetu.</li>
        <li style="margin-bottom: 6px;">Swój kod polecenia (8 znaków) i link z kodem znajdziesz w e-BOK i w aplikacji. Wysyłasz go sam, komu chcesz. Nie podajesz nam numeru sąsiada.</li>
        <li style="margin-bottom: 6px;">Sąsiad podaje kod w formularzu na stronie, przez telefon albo najpóźniej przy podpisaniu umowy. Po podpisaniu umowy kodu nie da się dopisać.</li>
        <li style="margin-bottom: 6px;">Sąsiad jest nowym klientem (nie korzystał z naszych usług od ponad 90 dni) i podłącza internet pod innym adresem niż Twój.</li>
        <li style="margin-bottom: 6px;">Rabat dotyczy abonamentu za internet (bez telewizji, Mesh i telefonu) i jest na fakturze. Nalicza się, gdy sąsiad ma uruchomiony internet i opłaci pierwszą fakturę.</li>
        <li>Nagrodę polecającego dostajesz za maksymalnie 6 osób w roku i wtedy, gdy nie masz zaległości. Rabatu nie wymieniamy na gotówkę. Program łączy się z Promocją Mikołajową.</li>
      </ol>
    </div>
  </section><!--/ut:polecenia-->
'''

REGULAMIN = '''<!doctype html>
<html lang="pl">
<head>
<meta charset="utf-8">
<title>Regulamin programu „Poleć sąsiada” – UltraTech</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<link rel="stylesheet" href="/przyklad-mikolaj/assets/fonts/manrope.css">
<style>
body{margin:0;background:#FBF7F1;color:#1B1F24;font:16px/1.6 Manrope,system-ui,sans-serif}
a{color:#0B2545}
.w{max-width:820px;margin:0 auto;padding:32px 16px 64px;box-sizing:border-box}
h1{font-size:30px;line-height:1.2;color:#0B2545;margin:12px 0 6px}
h2{font-size:19px;color:#0B2545;margin:28px 0 8px}
ol{padding-left:22px;margin:0}
li{margin:0 0 6px}
.top{background:#FFF4D6;color:#5A4300;padding:6px 16px;text-align:center;font-size:13px}
.note{background:#fff;border:1.5px solid #E9DFD0;border-radius:12px;padding:12px 16px;font-size:15px}
</style>
</head>
<body>
<div class="top">Wersja robocza nowej strony</div>
<div class="w">
<a href="./">← Strona główna</a>
<h1>Regulamin programu „Poleć sąsiada”</h1>
<p style="margin:0;color:#4A5563">Wersja z 13.11.2026</p>

<h2>§ 1. Organizator i czas trwania</h2>
<ol>
<li>Organizatorem programu „Poleć sąsiada” (dalej: Program) jest UT sp. z o.o., ul. Królewska 57, 30-081 Kraków, KRS 0000447936, NIP 9442244353 (dalej: UT).</li>
<li>Program trwa od dnia ogłoszenia jego startu na stronie ultratech.net.pl do dnia jego odwołania, ogłoszonego na tej stronie z co najmniej 14-dniowym wyprzedzeniem.</li>
<li>Polecenia zapisane przed zakończeniem Programu rozliczamy na zasadach z dnia zapisania kodu, także po zakończeniu Programu.</li>
</ol>

<h2>§ 2. Kto może brać udział</h2>
<ol>
<li>Polecający to konsument, który ma z UT umowę o świadczenie usługi dostępu do internetu i aktywną usługę.</li>
<li>Polecony to konsument, który zawiera z UT nową umowę o dostęp do internetu i: a) nie korzystał z usług UT przez ostatnie 90 dni pod adresem instalacji ani z podanym numerem telefonu, b) podłącza usługę pod innym adresem niż adresy instalacji Polecającego, c) nie jest Polecającym ani osobą z jego gospodarstwa domowego.</li>
<li>W Programie nie biorą udziału przedsiębiorcy oraz pracownicy i współpracownicy UT i osoby z ich gospodarstw domowych. Nie można polecić samego siebie.</li>
</ol>

<h2>§ 3. Kod polecenia</h2>
<ol>
<li>Każdy Polecający otrzymuje stały kod polecenia złożony z 8 znaków i link z kodem. Kod jest widoczny w e-BOK i w aplikacji UltraTech. Kod nie zawiera danych osobowych.</li>
<li>Polecający sam przekazuje kod lub link wybranym osobom. UT nie przyjmuje od Polecającego numerów telefonów ani innych danych osób, którym chce polecić usługi, i nie kontaktuje się z nimi z jego inicjatywy.</li>
<li>Polecony podaje kod w formularzu na stronie, telefonicznie albo najpóźniej przy podpisaniu umowy. Po podpisaniu umowy kodu nie można dopisać.</li>
<li>Jedna umowa może mieć jednego Polecającego. Gdy Polecony poda kilka kodów, liczy się pierwszy zapisany. O przypisaniu polecenia rozstrzyga kod wpisany w umowie Poleconego.</li>
<li>UT może wyłączyć kod w razie nadużycia lub na prośbę Polecającego i nadać nowy. Polecenia zapisane wcześniej pozostają ważne.</li>
</ol>

<h2>§ 4. Nagroda Poleconego</h2>
<ol>
<li>Polecony płaci 1 zł brutto za abonament za internet w 4. miesiącu umowy. Rabat jest udzielany na fakturze.</li>
<li>Warunki: umowa zawarta z kodem polecenia, uruchomiona usługa i opłacona pierwsza faktura. Jeśli warunki zostaną spełnione po 4. miesiącu umowy, rabat obejmie najbliższy miesiąc rozliczeniowy.</li>
<li>Przykład: przy pakiecie 350/350 Mb/s w Promocji Mikołajowej 2026 abonament w 4. miesiącu wynosi 59 zł, więc Polecony płaci 1 zł, czyli 58 zł mniej.</li>
<li>Nagroda Poleconego nie zależy od liczby poleceń Polecającego ani od stanu jego rozliczeń z UT.</li>
</ol>

<h2>§ 5. Nagroda Polecającego</h2>
<ol>
<li>Polecający płaci 1 zł brutto za abonament za internet w miesiącu następującym po opłaceniu przez Poleconego pierwszej faktury. Rabat jest udzielany na fakturze.</li>
<li>Warunek: w dniu naliczenia rabatu Polecający ma aktywną usługę i nie ma zaległości wobec UT.</li>
<li>Polecający otrzymuje najwyżej 6 nagród w roku kalendarzowym. Kolejne nagrody są naliczane w kolejnych miesiącach. Limit nie ogranicza nagrody Poleconego.</li>
</ol>

<h2>§ 6. Zasady wspólne</h2>
<ol>
<li>Rabat dotyczy wyłącznie abonamentu za dostęp do internetu, bez telewizji, Home Mesh, usług telefonicznych i opłat jednorazowych.</li>
<li>Program łączy się z Promocją Mikołajową 2026 oraz z innymi promocjami UT, o ile ich regulaminy nie stanowią inaczej.</li>
<li>Rabat z Programu nie powiększa ulgi podlegającej zwrotowi przy rozwiązaniu umowy przed końcem okresu zobowiązania.</li>
<li>Gdy Polecony odstąpi od umowy, nagrody za to polecenie nie przysługują.</li>
<li>Nagród nie wymieniamy na gotówkę ani inne świadczenia.</li>
</ol>

<h2>§ 7. Informacje o poleceniach</h2>
<ol>
<li>Polecający widzi w e-BOK i w aplikacji datę i status swoich poleceń, bez danych Poleconych.</li>
<li>Polecający, który ma usługę w UT, może otrzymać SMS o podpisaniu umowy z jego polecenia i o naliczeniu rabatu. Wiadomości nie zawierają danych Poleconego.</li>
<li>UT nie informuje Poleconego, kto go polecił.</li>
</ol>

<h2>§ 8. Dane osobowe</h2>
<ol>
<li>Administratorem danych jest UT. Kontakt z inspektorem ochrony danych: iod@ultratech.net.pl.</li>
<li>Kod polecenia wskazuje Polecającego, dlatego UT przetwarza go w celu wykonania tego regulaminu (art. 6 ust. 1 lit. b RODO). Dane Poleconego UT przetwarza w celu obsługi jego zapytania i umowy.</li>
<li>Strona internetowa zapamiętuje kod z linku tylko na czas wizyty w pamięci przeglądarki, bez plików cookies. Więcej w <a href="/polityka-prywatnosci.php">Polityce prywatności</a> i <a href="dok/RODO.pdf">klauzuli RODO</a>.</li>
</ol>

<h2>§ 9. Reklamacje i zmiany</h2>
<ol>
<li>Reklamacje dotyczące Programu można składać na adres bok@ultratech.net.pl, telefonicznie pod numerem 729 910 600 albo pisemnie na adres UT. Odpowiadamy w ciągu 30 dni.</li>
<li>Zmiana regulaminu nie narusza praw nabytych przed zmianą. Regulamin jest dostępny na stronie ultratech.net.pl.</li>
</ol>
<p class="note" style="margin-top:28px">Masz pytanie o program? Zadzwoń: <a href="tel:729910600">729 910 600</a> albo napisz: <a href="mailto:bok@ultratech.net.pl">bok@ultratech.net.pl</a>.</p>
</div>
</body>
</html>
'''

s = open(os.path.join(SRC, 'index.html'), encoding='utf-8').read()
s = common(s, '')
s = rep(s, '<!--ut:cta-koniec-->', SEKCJA + '  <!--ut:cta-koniec-->')
open(os.path.join(DST, 'index.html'), 'w', encoding='utf-8').write(s)
open(os.path.join(DST, 'regulamin_polecen.html'), 'w', encoding='utf-8').write(REGULAMIN)
n = 0
for fn in sorted(os.listdir(os.path.join(SRC, 'network'))):
    if fn.endswith('.html'):
        s = open(os.path.join(SRC, 'network', fn), encoding='utf-8').read()
        s = common(s, '../')
        open(os.path.join(DST, 'network', fn), 'w', encoding='utf-8').write(s)
        n += 1
print('index + regulamin + podstron:', n)

# ---------------------------------------------------------------- K2: plakietki "X zl mniej" zdjete
# Przed 16.11 umowa 24 mies. kosztowala 69/79/89 zl (strona produkcyjna 13.11), wiec porownanie z cennikiem od 16.11 (85/95/105) wprowadzaloby w blad.
for fn in ['index.html'] + ['network/' + f for f in os.listdir(os.path.join(DST, 'network')) if f.endswith('.html')]:
    p = os.path.join(DST, fn)
    s = open(p, encoding='utf-8').read()
    s, c = re.subn(r'\s*<div class="oszcz">[^<]*<small>[^<]*</small></div>', '', s)
    assert c == 3, (fn, c)
    open(p, 'w', encoding='utf-8').write(s)
print('plakietki oszczednosci usuniete')
