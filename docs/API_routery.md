# API routerów WiFi mesh (zaślepki dla projektu WiFi_openwrt)

Stan: aplikacja i panel mają gotowy interfejs, a wywołania poniżej są **zaślepkami**.
W trybie pokazowym działają na danych przykładowych (Uplink AX34H + V-SOL jako węzeł).
Kiedy projekt WiFi_openwrt da zarządzanie routerami (np. przez EYE + TR-069/USP albo własny agent na OpenWrt),
wystarczy wystawić te ścieżki pod `/api/v1/klient/routery...` i dopisać je do listy dozwolonych w proxy.

Autoryzacja jak reszta API klienta: `Authorization: Bearer <token>`.
Odczyt: poziom 1 (ID + PIN). **Zmiany: poziom 2** (kod SMS), bo zmieniają ustawienia sprzętu klienta.
Brak poziomu: `403 {blad, wymagany_poziom: 2}`.

| Metoda i ścieżka | Ciało / odpowiedź | Opis |
|---|---|---|
| `GET /klient/routery` | `{routery: [{id, model, nazwa, glowny, online, firmware, nowy_firmware?, klienci, jakosc_polaczenia?}]}` | lista routerów i węzłów mesh klienta |
| `GET /klient/routery/wifi` | `{ssid, siec_5g_osobno, gosc, ssid_gosc?}` | ustawienia sieci (hasła nigdy nie są zwracane) |
| `PUT /klient/routery/wifi` | `{ssid, haslo?, gosc?, haslo_gosc?}` | zmiana nazwy/hasła na wszystkich węzłach mesh |
| `PATCH /klient/routery/{id}` | `{nazwa}` | nazwa węzła („Salon”, „Piętro”) |
| `POST /klient/routery/{id}/restart` | – | restart jednego routera |
| `POST /klient/routery/{id}/firmware` | – | aktualizacja do `nowy_firmware` (firmware z WiFi_openwrt) |
| `POST /klient/routery/parowanie` | – | główny router przez 2 min przyjmuje nowy węzeł mesh (jak WPS/EasyMesh) |

Uwagi dla WiFi_openwrt:
- `model` to nazwa handlowa (Uplink AX34H, V-SOL …), `firmware` to wersja UT-OpenWrt.
- `jakosc_polaczenia` (dobra/slaba) dotyczy łącza węzła do routera głównego, przyda się do porad „przestaw punkt bliżej”.
- Zmiana hasła WiFi powinna zwracać 202 i działać w tle; aplikacja mówi klientowi, że zmiana nastąpi w ciągu minuty.
- Warto logować w EYE każdą zmianę (kto, kiedy, z jakiego poziomu), żeby BOK widział, że klient sam zmienił hasło.

Kod: `lib/api/api.dart` (klasa `HttpApi`, sekcja „Routery mesh”), ekran: `lib/screens/routery_ekran.dart`.
