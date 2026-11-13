# Poprawki z audytu marketingowego 13.11.2026 – strona robocza przyklad-mikolaj

Pakiet do wgrania na serwer 193.242.142.10, katalog /var/www/html/przyklad-mikolaj/ (TYLKO strona robocza).

- www/index.html          -> /var/www/html/przyklad-mikolaj/index.html
- www/network/*.html (57) -> /var/www/html/przyklad-mikolaj/network/
- MD5SUMS                 sumy kontrolne plików z www/
- poprawki.py             skrypt, który z plików pobranych z serwera 13.11 (14:20 UTC) zrobił www/
                          (python3 poprawki.py WEJ WYJ zrodla/panorama_57_wieczor_wstawka_v3.html zrodla/mapa_A_siec_v1.svg)
- zrodla/                 panorama wieczorna v3 i mapa zasięgu A v1

Zmiany: audyt A1, A2 (częściowo – zapis zgody wymaga zmiany zamowienie.php), pkt 1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, C6, C8.
