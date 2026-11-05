# UltraTech: aplikacja abonencka (Android, iPhone, Windows, macOS, Linux) i panel klienta (web)

Jeden kod we Flutterze buduje: aplikację na Androida i iPhone'a, aplikację na komputer (Windows, macOS, Linux)
i panel w przeglądarce. **Wersji na komputer nie pokazujemy jeszcze na stronie www** (decyzja z 05.11.2026).

## Co jest w aplikacji

| Zakładka | Co robi | Logowanie |
|---|---|---|
| **Start** | aktualności serwisowe (awarie, prace planowe, informacje) i promocyjne, filtr, szybkie przyciski, telefon do biura | nie; po zalogowaniu także komunikaty dla okolicy klienta |
| **Test łącza** | diagnoza z EYE krok po kroku z paskiem postępu: konto, ONU, sesja, port LAN (negocjacja, ruch), automatyczny restart z OLT, gdy nie ma sesji, sprawdzenie po restarcie; dostęp warunkowy przy blokadzie (raz na ok. 2 miesiące); test prędkości do serwera w sieci UT (pobieranie i wysyłanie w Mb/s; opóźnienie i dostępność 30 polskich serwisów tylko jako werdykt OK / nie OK, dokładne czasy idą wyłącznie w zgłoszeniu do EYE, decyzja z 05.11.2026) | diagnoza: poziom 1; dostęp warunkowy: poziom 3; test prędkości bez logowania |
| **Awaria** | formularz zgłoszenia jak w e-Pol, dołączenie wyniku testu, „Moje zgłoszenia” | poziom 1, wysłanie: poziom 2 (poziom 3, gdy EYE tego wymaga, np. ujemne saldo) |
| **Mój WiFi** | sieć WiFi (nazwa, hasło, sieć dla gości), lista routerów mesh, restart, aktualizacja firmware, dodanie punktu mesh | podgląd: poziom 1, zmiany: poziom 2; **zaślepki** do czasu API z WiFi_openwrt |

Poziomy dostępu (decyzja z 04.11.2026):
1. ID klienta z net47 + PIN e-BOK,
2. kod SMS na dowolny numer kontaktowy,
3. kod SMS na numer zapisany w net47, wpisany przez klienta bez podpowiedzi.

Aplikacja nie pokazuje salda, nazwiska, e-maila ani loginu PPPoE i nie zapisuje PIN-u.
Token: w telefonie w Keychain/Keystore, w przeglądarce tylko w pamięci karty.

## Tryb pokazowy

Domyślnie `DEMO=true`: aplikacja nie łączy się z EYE. Dane do prób: dowolne ID i PIN `1234`
(ID `999` ma dwa przyłącza, drugie „nie działa”; `1002` usługa wstrzymana i dostęp warunkowy; `1003` brak sesji i restart z OLT),
kod SMS `123456`, numer z umowy `600100200`.
Wersja produkcyjna: `--dart-define=DEMO=false`.

## Budowa

```
flutter pub get
flutter test
flutter build apk --release --dart-define=DEMO=false                     # Android
flutter build ios --release --dart-define=DEMO=false                     # iPhone (tylko na Macu, konto Apple Developer)
flutter build linux --release                                            # Linux (libgtk-3-dev, libsecret-1-dev)
flutter build windows --release                                          # Windows (na Windows, Visual Studio)
flutter build macos --release                                            # macOS (na Macu)
flutter build web --release --no-web-resources-cdn --base-href /panel/ \
  --dart-define=DEMO=false --dart-define=API_URL=/api/v1 --dart-define=APP_FILES_URL=/app   # panel web
```

Bez Maca i komputera z Android SDK: wrzuć projekt do repozytorium GitHub, a `.github/workflows/build.yml`
zbuduje APK, sprawdzi kompilację na iOS i zbuduje panel web (pliki do pobrania w zakładce Actions).

Adresy (`lib/config.dart`, nadpisywane `--dart-define`):
`API_URL` (proxy API klienta EYE), `APP_FILES_URL` (manifest wersji, zapasowe aktualności), `SPEEDTEST_URL` (LibreSpeed).

## Podpis Androida

```
keytool -genkey -v -keystore ut-release.jks -keyalg RSA -keysize 4096 -validity 10000 -alias ut
```
`android/key.properties` (nie do repozytorium):
```
storeFile=../app/ut-release.jks
storePassword=...
keyAlias=ut
keyPassword=...
```
Klucz trzeba przechować bezpiecznie: bez niego nie da się wydać aktualizacji tej samej aplikacji.

## Auto-aktualizacja

`lib/services/aktualizacje.dart` + `server/app/wersja.json`. Opis wydawania wersji: `server/README.md`.
- Android z pliku APK: pobiera nowy APK w aplikacji, sprawdza SHA-256, otwiera instalator systemu.
- Android z Google Play: otwiera Sklep Play. Do wersji na Play usuń `REQUEST_INSTALL_PACKAGES` i provider z `AndroidManifest.xml`.
- iPhone: otwiera App Store (Apple nie pozwala na samodzielną instalację).
- Windows, macOS, Linux: pole `pobierz` w `wersja.json`, aplikacja otwiera nową wersję w przeglądarce.
- Panel web: aktualizuje się sam przy wgraniu nowych plików.
- `min_kod` wymusza aktualizację, gdy zmieni się API.

## Bez usług Google

Czcionka Manrope (jak na ultratech.net.pl) jest w paczce aplikacji (`assets/fonts`, licencja OFL), a panel web budujemy z
`--no-web-resources-cdn`, więc ani aplikacja, ani panel nie pobierają niczego z serwerów Google. Aplikacja nie używa
powiadomień Google (Firebase). Jedyny link do Google to Sklep Play przy aktualizacji wersji pobranej z Play.

## Diagnoza i dostęp warunkowy (API EYE, uzgodnione z wątkiem EYE)

- `POST /klient/diagnoza` → `{id}`; `GET /klient/diagnoza/{id}` co 1–2 s, każde wywołanie wykonuje jeden krok (do 30 s),
  aż `koniec: true`. Kroki: konto, onu, sesja, lan, lan_ping, brama, polska (OK, gdy odpowie co najmniej 10 z 30 serwisów), restart_olt, internet; kroki z pingami pokazują tylko werdykt; stan: czeka|trwa|ok|uwaga|blad|pominiety.
- `GET /klient/dostep-warunkowy` → `{mozliwy, aktywny, powod?, nastepny_od?, dni}`; `POST` włącza (poziom 3).

## Test pod obciążeniem (05.11.2026)

- Przed pobieraniem aplikacja woła `POST /klient/obciazenie/start` (EYE zaczyna liczyć liczniki portu LAN ONU i pingi),
  potem pobieranie i wysyłanie, każde ok. 11,5 s; pierwsze 3,5 s (boost) się nie liczy. Okna bez boostu (ms od odpowiedzi startu)
  idą w `POST /klient/obciazenie/{id}/wynik` razem z Mb/s, opóźnieniem pod obciążeniem (próbka co 250 ms), rodzajem połączenia
  (Wi-Fi / kabel do routera / kabel do terminala / komórkowe, wykrywane z systemu albo wybrane przez klienta) i `metoda` (http | iperf3).
- `GET /klient/obciazenie/{id}` daje dwa werdykty OK / nie OK: „Łącze UltraTech do Twojego routera” i „Twój router i Wi-Fi”;
  przy nie OK aplikacja proponuje test po kablu. Wszystkie próby (Wi-Fi, kabel) trafiają do raportu zgłoszenia.
- Gdy `obciazenie/start` się nie uda (np. 429), zalogowany klient wysyła wynik do `POST /klient/obciazenie/zapis` (to samo body, bez werdyktu, błędy pomijane), żeby trafił do karty klienta w EYE.
- ONU jest w teście tylko bierne (liczniki, pingi), nie jest końcem pomiaru; routery Wi-Fi też nie.

## iperf3 (tylko aplikacja: telefon i komputer)

- Własny klient protokołu iperf3 w Darcie (`lib/services/iperf3.dart`), bez programu iperf3 na urządzeniu.
  Serwer: kontener iperf3 na CCR2216 z `--rsa-private-key-path` i `--authorized-users-path`; sprawdzone z iperf3 3.16
  (pobieranie `-R` i wysyłanie, 4 strumienie, omit 3 s). Przeglądarka nie ma gniazd TCP i zostaje na HTTP (OpenSpeedTest / LibreSpeed).
- Jeden serwer iperf3 obsługuje jednego klienta naraz, dlatego warto postawić kilka instancji na kolejnych portach;
  aplikacja losuje port, zajęty lub nieosiągalny pomija, a gdy żaden nie działa, robi fazę przez HTTP.
- Budowa (dane nie trafiają do repozytorium):
  `--dart-define=IPERF_HOST=192.168.253.1 --dart-define=IPERF_PORTY=5201-5204 --dart-define=IPERF_USER=... --dart-define=IPERF_PASS=... --dart-define=IPERF_PUBKEY=<base64 klucza publicznego>`.
  Token RSA: PKCS#1 v1.5 jak w iperf3 3.16 (`IPERF_PKCS1=true`, domyślnie). Dla serwera 3.17+ trzeba mu dać `--use-pkcs1-padding`.
  Zegar telefonu musi być ustawiony (serwer odrzuca token starszy niż ok. 10 s).
- Test na żywym serwerze: `IPERF_HOST=... IPERF_PORT=... IPERF_PEM=pub.pem IPERF_USER=... IPERF_PASS=... IPERF_HTTP=<adres z empty.php> flutter test --dart-define=DEMO=false test/iperf3_live_test.dart`.

## macOS

Przed wydaniem trzeba ustawić zespół podpisu w Xcode i dodać „Keychain Sharing”, inaczej logowanie nie zapamięta tokenu.

## Zależności po stronie serwera

- Proxy API klienta i łatka EYE: wątek „test łącza i zgłaszanie awarii” (`strona/pomoc/`).
- Komunikaty serwisowe w EYE: wątek „komunikaty serwisowe” (pola: id, typ, tytul, tresc, od, do, priorytet, przypiety, zaktualizowano).
- Routery mesh: `docs/API_routery.md`, do zrobienia w WiFi_openwrt.
- Test prędkości: LibreSpeed w sieci UT (`server/README.md`); w aplikacji iperf3 na CCR2216, gdy podano IPERF_HOST.

## Struktura

```
lib/config.dart                adresy, tryb pokazowy, telefony
lib/api/api.dart               jedyne miejsce rozmowy z EYE (HttpApi) + dane pokazowe (DemoApi)
lib/api/models.dart            modele danych
lib/services/                  logowanie i poziomy, test prędkości, auto-aktualizacja
lib/screens/                   ekrany
test/                          testy (poziomy, aktualizacje, zgodność z proxy API)
```

Do uzupełnienia przed publikacją: ikona aplikacji w wysokiej rozdzielczości (obecne logo ma 65×65 px),
polityka prywatności (wymagana przez sklepy), konto Google Play (25 USD jednorazowo) i Apple Developer (99 USD/rok).
