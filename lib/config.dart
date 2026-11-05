/// Ustawienia aplikacji. Adresy można nadpisać przy budowie, np.:
///   flutter build apk --dart-define=API_URL=https://api.ultratech.net.pl/api/v1 --dart-define=DEMO=false
class Config {
  /// Publiczny adres API klienta EYE (reverse proxy tylko na /api/v1/klient/ i /api/v1/komunikaty).
  static const apiUrl = String.fromEnvironment('API_URL',
      defaultValue: 'https://api.ultratech.net.pl/api/v1');

  /// Pliki statyczne aplikacji na serwerze www (manifest wersji, aktualności zapasowe).
  static const appFilesUrl = String.fromEnvironment('APP_FILES_URL',
      defaultValue: 'https://ultratech.net.pl/app');

  /// Serwer testu prędkości zgodny z LibreSpeed (backend/empty.php, garbage.php, getIP.php).
  static const speedtestUrl = String.fromEnvironment('SPEEDTEST_URL',
      defaultValue: 'https://speedtest.ultratech.net.pl/backend');

  /// iperf3 na CCR2216 (kontener) – tylko aplikacja na telefon i komputer, przeglądarka zostaje na HTTP.
  /// Pusty IPERF_HOST = test przez HTTP jak w przeglądarce. Serwer iperf3 obsługuje jednego klienta naraz,
  /// dlatego kilka instancji na kolejnych portach (IPERF_PORTY=5201-5204); aplikacja losuje wolny port.
  /// Hasło i klucz publiczny RSA podawane przy budowie, nie trzymamy ich w repozytorium.
  static const iperfHost = String.fromEnvironment('IPERF_HOST');
  static const iperfPorty = String.fromEnvironment('IPERF_PORTY', defaultValue: '5201-5204');
  static const iperfUzytkownik = String.fromEnvironment('IPERF_USER');
  static const iperfHaslo = String.fromEnvironment('IPERF_PASS');
  /// Klucz publiczny PEM w jednej linii (base64 bez nagłówków) albo pełny PEM.
  static const iperfKlucz = String.fromEnvironment('IPERF_PUBKEY');
  /// iperf3 3.16 i `--use-pkcs1-padding`: true; serwer 3.17+ bez tej opcji: false (OAEP).
  static const iperfPkcs1 = bool.fromEnvironment('IPERF_PKCS1', defaultValue: true);

  static List<int> get portyIperf {
    final w = <int>[];
    for (final cz in iperfPorty.split(',')) {
      final z = cz.trim().split('-').map(int.tryParse).toList();
      if (z.length == 2 && z[0] != null && z[1] != null) {
        for (var p = z[0]!; p <= z[1]!; p++) {
          w.add(p);
        }
      } else if (z.length == 1 && z[0] != null) {
        w.add(z[0]!);
      }
    }
    return w;
  }

  /// Tryb demonstracyjny: aplikacja nie łączy się z EYE, tylko pokazuje dane przykładowe.
  /// Domyślnie włączony, dopóki API EYE nie jest wystawione publicznie.
  static const demo = bool.fromEnvironment('DEMO', defaultValue: true);

  static const telefonBiuro = '729910600';
  static const telefonBiuroLadny = '729 910 600';
  static const email = 'bok@ultratech.net.pl';
  static const ebokUrl = 'https://ebok.ultratech.net.pl/';
  static const stronaUrl = 'https://ultratech.net.pl/';

  /// Identyfikatory sklepów do aktualizacji (uzupełnić po publikacji).
  static const appStoreUrl = String.fromEnvironment('APP_STORE_URL',
      defaultValue: 'https://apps.apple.com/pl/app/id0000000000');
  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=pl.net.ultratech.ut_abonent';
}
