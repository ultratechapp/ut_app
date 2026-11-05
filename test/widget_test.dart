import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ut_abonent/api/api.dart';
import 'package:ut_abonent/main.dart';
import 'package:ut_abonent/services/aktualizacje.dart';
import 'package:ut_abonent/services/ranking_serwisow.dart';
import 'package:ut_abonent/services/rodzaj_sieci.dart';
import 'package:ut_abonent/services/test_predkosci.dart';
import 'package:ut_abonent/services/stan_aplikacji.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Ekran główny pokazuje aktualności i przyciski', (t) async {
    await t.pumpWidget(AplikacjaUT(stan: StanAplikacji(DemoApi())));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Aktualności'), findsOneWidget);
    expect(find.text('Prace serwisowe w Medyce'), findsOneWidget);
    await t.tap(find.text('Promocje'));
    await t.pump();
    expect(find.text('Prace serwisowe w Medyce'), findsNothing);
    expect(find.text('Mikołajowy Światłowód 2026'), findsOneWidget);
  });

  testWidgets('Zakładka Awaria wymaga logowania', (t) async {
    await t.pumpWidget(AplikacjaUT(stan: StanAplikacji(DemoApi())));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byIcon(Icons.report_problem_outlined).last);
    await t.pumpAndSettle();
    expect(find.text('Zaloguj ID klienta i PIN-em'), findsOneWidget);
  });

  group('Poziomy dostępu (demo)', () {
    test('ID+PIN daje poziom 1, SMS poziom 2, numer z umowy poziom 3', () async {
      final s = StanAplikacji(DemoApi());
      await s.zaloguj('123', '1234');
      expect(s.poziom, 1);
      await s.wyslijKod('500 600 700', rozszerzony: false);
      await s.potwierdzKod('123456');
      expect(s.poziom, 2);
      await expectLater(s.wyslijKod('500600700', rozszerzony: true), throwsA(anything));
      await s.wyslijKod('600100200', rozszerzony: true);
      await s.potwierdzKod('123456');
      expect(s.poziom, 3);
    });

    test('Zły PIN odrzucony', () async {
      final s = StanAplikacji(DemoApi());
      await expectLater(s.zaloguj('123', '0000'), throwsA(anything));
      expect(s.zalogowany, false);
    });
  });

  test('Diagnoza demo: brak sesji wywołuje restart z OLT, postęp rośnie do 100%', () async {
    final api = DemoApi();
    await api.zaloguj('999', '1234');
    final id = await api.startDiagnozy('demo', przylacze: 'p2');
    var d = await api.krokDiagnozy('demo', id);
    expect(d.kroki.first.stan, 'trwa');
    var poprzedni = d.postep;
    while (!d.koniec) {
      d = await api.krokDiagnozy('demo', id);
      expect(d.postep, greaterThanOrEqualTo(poprzedni));
      poprzedni = d.postep;
    }
    expect(d.postep, 1);
    expect(d.kroki.firstWhere((k) => k.kod == 'restart_olt').stan, 'ok');
    expect(d.kroki.firstWhere((k) => k.kod == 'lan').stan, 'pominiety');
  });

  test('Dostęp warunkowy demo: blokada, potem włączony', () async {
    final api = DemoApi();
    await api.zaloguj('1002', '1234');
    final id = await api.startDiagnozy('demo');
    await api.krokDiagnozy('demo', id);
    final d = await api.krokDiagnozy('demo', id);
    expect(d.ocena, 'blokada');
    expect(d.dostepWarunkowy, true);
    expect((await api.dostepWarunkowy('demo')).mozliwy, true);
    await api.wlaczDostepWarunkowy('demo');
    expect((await api.dostepWarunkowy('demo')).aktywny, true);
  });

  test('Serwisy: OK od 10 odpowiadających z 30, do zgłoszenia idą czasy', () async {
    expect(RankingSerwisow.hosty.length, 30);
    final r = (await RankingSerwisow.zmierz(demo: true))!;
    expect(RankingSerwisow.ok(r), true);
    final malo = [for (var i = 0; i < 30; i++) (host: 'h$i', ms: i < 9 ? 20 : null)];
    expect(RankingSerwisow.ok(malo), false);
    expect(RankingSerwisow.doZgloszenia(malo)[10], {'host': 'h10', 'ms': null});
  });

  test('Mediana i p90 do opóźnienia pod obciążeniem', () {
    expect(mediana([5, 1, 3]), 3);
    expect(percentyl([for (var i = 1; i <= 11; i++) i.toDouble()], 90), 10);
  });

  test('Rozpoznanie Wi-Fi z poleceń systemu', () {
    expect(RodzajSieci.parsujNmcli('no:40:130 Mbit/s:2437 MHz\nyes:72:540 Mbit/s:5180 MHz'), (-64, 540, 5180));
    expect(RodzajSieci.parsujNetsh('    Channel                : 36\n    Receive rate (Mbps)    : 866.7\n    Signal                 : 80%'),
        (-60, 866, 5200));
    expect(RodzajSieci.parsujMac('Current Network Information:\n Channel: 149 (5GHz, 80MHz)\n Signal / Noise: -58 dBm / -92 dBm\n Transmit Rate: 866'),
        (-58, 866, 5200));
    expect(RodzajSieci.pasmo(5180), '5 GHz');
  });

  test('Test pod obciążeniem (demo): start EYE przed pobieraniem, okna bez boostu, werdykty odcinków', () async {
    final api = DemoApi();
    final t = TestPredkosci();
    var wolanoStart = false;
    late final dynamic wynik;
    await for (final _ in t.uruchom(
        polaczenie: 'wifi',
        startObciazenia: () async {
          wolanoStart = true;
          return api.obciazenieStart('demo');
        },
        gotowe: (w) => wynik = w)) {}
    expect(wolanoStart, true);
    expect(wynik.idObciazenia, 'o1');
    expect(t.okna.pobieranie!.$1, greaterThanOrEqualTo(3500));
    expect(t.okna.wysylanie!.$2, lessThanOrEqualTo(25000));
    await api.obciazenieWynik('demo', 'o1', {'polaczenie': {'rodzaj': 'wifi'}});
    var o = await api.obciazenieStan('demo', 'o1');
    while (!o.koniec) {
      o = await api.obciazenieStan('demo', 'o1');
    }
    expect(o.odcinki.map((e) => e.stan), ['ok', 'blad']);
    expect(o.proponujTestKabel, true);
    expect(wynik.doRaportu(), contains('bez boostu'));
  });

  group('Auto-aktualizacja', () {
    final manifest = {
      'android': {'wersja': '1.2.0', 'kod': 5, 'min_kod': 3, 'apk': 'https://x/a.apk', 'sha256': 'ab', 'zmiany': 'Poprawki'},
      'ios': {'wersja': '1.2.0', 'kod': 5, 'min_kod': 1, 'sklep': 'https://apps.apple.com/x'},
    };
    test('brak aktualizacji przy tej samej wersji', () {
      expect(Aktualizacje.porownaj(manifest, 'android', 5), isNull);
    });
    test('zwykła aktualizacja z APK', () {
      final w = Aktualizacje.porownaj(manifest, 'android', 4)!;
      expect(w.wymagana, false);
      expect(w.apk, 'https://x/a.apk');
    });
    test('wymagana aktualizacja poniżej min_kod', () {
      expect(Aktualizacje.porownaj(manifest, 'android', 2)!.wymagana, true);
    });
    test('z Google Play nie pobiera APK, tylko otwiera sklep', () {
      final w = Aktualizacje.porownaj(manifest, 'android', 4, zeSklepu: true)!;
      expect(w.apk, isNull);
      expect(w.sklep, contains('play.google.com'));
    });
    test('Windows bez wpisu w manifeście: brak aktualizacji', () {
      expect(Aktualizacje.porownaj(manifest, 'windows', 1), isNull);
    });
    test('Linux: link do pobrania, bez APK i sklepu', () {
      final m = {
        'linux': {'wersja': '1.1.0', 'kod': 2, 'pobierz': 'https://x/UltraTech.AppImage', 'apk': 'https://x/a.apk'}
      };
      final w = Aktualizacje.porownaj(m, 'linux', 1)!;
      expect(w.pobierz, 'https://x/UltraTech.AppImage');
      expect(w.apk, isNull);
      expect(w.sklep, isNull);
    });
    test('iPhone kieruje do App Store', () {
      expect(Aktualizacje.porownaj(manifest, 'ios', 1)!.sklep, 'https://apps.apple.com/x');
    });
  });
}
