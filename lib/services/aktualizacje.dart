import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../platforma.dart';

/// Informacja o nowej wersji z pliku wersja.json na serwerze UT.
class NowaWersja {
  final String wersja;
  final int kod;
  final bool wymagana; // starsza wersja nie będzie działać (np. zmiana API)
  final String zmiany;
  final String? apk; // Android poza Google Play: bezpośredni link do pliku APK
  final String? sha256;
  final String? sklep; // link do App Store / Google Play
  final String? pobierz; // Windows, macOS, Linux: strona lub plik instalatora (otwierany w przeglądarce)
  NowaWersja(
      {required this.wersja,
      required this.kod,
      required this.wymagana,
      required this.zmiany,
      this.apk,
      this.sha256,
      this.sklep,
      this.pobierz});
}

/// Auto-aktualizacja.
///
/// Aplikacja przy starcie (najwyżej raz na 6 godzin) pobiera {APP_FILES_URL}/wersja.json.
/// Android z pliku APK (dystrybucja ze strony UT): pobiera nowy APK w aplikacji,
///   sprawdza sumę SHA-256 i otwiera systemowe okno instalacji.
/// Android z Google Play: otwiera stronę aplikacji w Sklepie Play
///   (Play i tak aktualizuje aplikacje automatycznie).
/// iPhone: Apple nie pozwala aplikacji instalować się samej, więc otwieramy App Store.
/// Windows, macOS, Linux: pole "pobierz" w manifeście, otwierane w przeglądarce
///   (instalator .msix/.exe, .dmg, AppImage). Linków do tych wersji nie ma jeszcze na stronie www.
/// Pole "min_kod" wymusza aktualizację, gdy stara wersja nie zadziała z nowym API.
class Aktualizacje {
  static const _klucz = 'ostatnie_sprawdzenie_aktualizacji';

  static String get _platforma => kluczPlatformy;

  static Future<NowaWersja?> sprawdz({bool wymus = false, http.Client? klient}) async {
    if (kIsWeb) return null;
    final prefs = await SharedPreferences.getInstance();
    final teraz = DateTime.now().millisecondsSinceEpoch;
    if (!wymus && teraz - (prefs.getInt(_klucz) ?? 0) < const Duration(hours: 6).inMilliseconds) {
      return null;
    }
    final info = await PackageInfo.fromPlatform();
    final r = await (klient ?? http.Client())
        .get(Uri.parse('${Config.appFilesUrl}/wersja.json?r=$teraz'))
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return null;
    await prefs.setInt(_klucz, teraz);
    return porownaj(jsonDecode(utf8.decode(r.bodyBytes)), _platforma, int.tryParse(info.buildNumber) ?? 0,
        zeSklepu: _zeSklepu(info));
  }

  /// Logika porównania wydzielona do testów.
  @visibleForTesting
  static NowaWersja? porownaj(Map<String, dynamic> manifest, String platforma, int mojKod, {bool zeSklepu = false}) {
    final m = manifest[platforma];
    if (m is! Map) return null;
    final kod = int.tryParse('${m['kod']}') ?? 0;
    if (kod <= mojKod) return null;
    final minKod = int.tryParse('${m['min_kod'] ?? 0}') ?? 0;
    return NowaWersja(
      wersja: '${m['wersja']}',
      kod: kod,
      wymagana: mojKod < minKod,
      zmiany: '${m['zmiany'] ?? ''}',
      apk: platforma == 'android' && !zeSklepu ? m['apk'] as String? : null,
      sha256: m['sha256'] as String?,
      sklep: switch (platforma) {
        'ios' => m['sklep'] as String? ?? Config.appStoreUrl,
        'android' => Config.playStoreUrl,
        _ => null,
      },
      pobierz: m['pobierz'] as String?,
    );
  }

  static bool _zeSklepu(PackageInfo info) {
    final s = info.installerStore ?? '';
    return s.contains('com.android.vending') || s.contains('com.apple');
  }

  /// Instaluje nową wersję. Zwraca strumień postępu w procentach (tylko Android z APK).
  static Stream<int> instaluj(NowaWersja w) async* {
    if (w.apk != null && defaultTargetPlatform == TargetPlatform.android) {
      await for (final e in OtaUpdate().execute(w.apk!,
          destinationFilename: 'ut_abonent-${w.wersja}.apk', sha256checksum: w.sha256)) {
        if (e.status == OtaStatus.DOWNLOADING) {
          yield int.tryParse(e.value ?? '') ?? 0;
        } else if (e.status == OtaStatus.INSTALLING || e.status == OtaStatus.INSTALLATION_DONE) {
          yield 100;
        } else if (e.status != OtaStatus.ALREADY_RUNNING_ERROR) {
          throw Exception('Nie udało się pobrać aktualizacji (${e.status.name}).');
        }
      }
    } else if (w.pobierz != null || w.sklep != null) {
      // Komputer: otwieramy instalator nowej wersji w przeglądarce. Telefon bez APK: sklep.
      await launchUrl(Uri.parse(w.pobierz ?? w.sklep!), mode: LaunchMode.externalApplication);
      yield 100;
    }
  }
}
