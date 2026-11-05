# Pliki po stronie serwera dla aplikacji i panelu

Nic z tego nie jest jeszcze wgrane. Wszystko wymaga zgody przed wgraniem na żywą stronę.

| Co | Gdzie na serwerze | Po co |
|---|---|---|
| `app/wersja.json` | `/var/www/html/app/wersja.json` | manifest auto-aktualizacji |
| `app/aktualnosci.json` | `/var/www/html/app/aktualnosci.json` | zapasowe aktualności, gdy EYE nie odpowiada |
| plik APK | `/var/www/html/app/ut_abonent-X.Y.Z.apk` | instalacja i aktualizacja na Androidzie spoza Google Play |
| panel web (`build/web`) | `/var/www/html/panel/` | panel klienta w przeglądarce |
| proxy API (wątek EYE) | `/var/www/html/api/` | `https://ultratech.net.pl/api/v1/klient/...` |
| LibreSpeed | osobny serwer w sieci UT, np. `speedtest.ultratech.net.pl` | test prędkości z telefonu i z panelu |

## Test prędkości (LibreSpeed)

Aplikacja mówi protokołem LibreSpeed (darmowy, licencja LGPL): `backend/empty.php` (ping i wysyłanie)
i `backend/garbage.php?ckSize=20` (pobieranie). Wystarczy postawić LibreSpeed na maszynie
podłączonej do rdzenia sieci UT, najlepiej 10 Gb/s, żeby serwer nie był wąskim gardłem:

```
docker run -d --name speedtest -p 80:80 -e MODE=backend ghcr.io/librespeed/speedtest
```

Wymagane nagłówki CORS dla panelu web (`Access-Control-Allow-Origin: https://ultratech.net.pl`).
Adres ustawia się przy budowie: `--dart-define=SPEEDTEST_URL=https://speedtest.ultratech.net.pl/backend`.

## Wydanie nowej wersji (Android, poza Google Play)

1. Podnieś `version:` w `pubspec.yaml`, np. `1.0.1+2`.
2. Zbuduj: `flutter build apk --release --dart-define=DEMO=false`.
3. Wgraj APK do `/var/www/html/app/` i policz sumę: `sha256sum ut_abonent-1.0.1.apk`.
4. W `wersja.json` ustaw `wersja`, `kod`, `apk`, `sha256`, `zmiany`. Aplikacja zauważy to przy następnym starcie
   (najwyżej co 6 godzin) albo od razu po „Sprawdź aktualizacje”.
5. Jeśli stara wersja nie zadziała z nowym API, podnieś `min_kod`: klient nie zamknie okna aktualizacji.

iPhone: Apple nie pozwala aplikacji aktualizować się samej. Po wydaniu w App Store podnieś `kod` w sekcji `ios`,
a aplikacja pokaże okno z przyciskiem do App Store.
