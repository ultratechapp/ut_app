@Tags(['siec'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ut_abonent/api/models.dart';
import 'package:ut_abonent/config.dart';
import 'package:ut_abonent/services/iperf3.dart';
import 'package:ut_abonent/services/test_predkosci.dart';

/// Test na żywym serwerze iperf3 (uruchamiany ręcznie):
///   IPERF_HOST=127.0.0.1 IPERF_PORT=5299 IPERF_PEM=/ścieżka/pub.pem IPERF_USER=ut_app IPERF_PASS=... \
///   flutter test test/iperf3_live_test.dart
void main() {
  final host = Platform.environment['IPERF_HOST'];
  test('iperf3: pobieranie i wysyłanie z uwierzytelnieniem RSA', () async {
    final pem = File(Platform.environment['IPERF_PEM']!).readAsStringSync();
    for (final pkcs1 in [true]) {
      final k = Iperf3(
          host: host!,
          port: int.parse(Platform.environment['IPERF_PORT'] ?? '5201'),
          uzytkownik: Platform.environment['IPERF_USER'],
          haslo: Platform.environment['IPERF_PASS'],
          kluczPublicznyPem: pem,
          pkcs1: pkcs1);
      try {
        final pob = await k.zmierz(pobieranie: true, czas: 2, omit: 1);
        final wys = await k.zmierz(pobieranie: false, czas: 2, omit: 1);
        // ignore: avoid_print
        print('pkcs1=$pkcs1 pob ${pob.mbps.toStringAsFixed(0)} (serwer ${pob.mbpsSerwer.toStringAsFixed(0)}, retr ${pob.retransmisje}) '
            'wys ${wys.mbps.toStringAsFixed(0)} (serwer ${wys.mbpsSerwer.toStringAsFixed(0)}) Mb/s');
        expect(pob.mbps, greaterThan(10));
        expect(wys.mbps, greaterThan(10));
      } finally {}
    }
  }, skip: host == null ? 'brak IPERF_HOST' : false, timeout: const Timeout(Duration(minutes: 2)));

  test('test prędkości przez iperf3 z próbkami opóźnienia HTTP i zapasowym portem', () async {
    final pem = File(Platform.environment['IPERF_PEM']!).readAsStringSync();
    final port = int.parse(Platform.environment['IPERF_PORT'] ?? '5201');
    Iperf3 serwer(int p) => Iperf3(
        host: host!, port: p, uzytkownik: Platform.environment['IPERF_USER'], haslo: Platform.environment['IPERF_PASS'], kluczPublicznyPem: pem);
    final t = TestPredkosci(
      url: Platform.environment['IPERF_HTTP'],
      czasFazy: const Duration(seconds: 5),
      pominBoost: const Duration(seconds: 2),
      iperf: [serwer(port), serwer(port + 1)], // port+1 nie działa: aplikacja przechodzi na następny
    );
    WynikTestu? w;
    await t.uruchom(polaczenie: 'kabel_router', startObciazenia: () async => 'abc', gotowe: (x) => w = x).drain<void>();
    // ignore: avoid_print
    print(w!.doRaportu());
    // ignore: avoid_print
    print(t.okna.toJson());
    expect(w!.metoda, 'iperf3');
    expect(w!.pobieranieMbps, greaterThan(10));
    expect(w!.wysylanieMbps, greaterThan(10));
    expect(t.okna.pobieranie, isNotNull);
    expect(t.okna.wysylanie!.$2, lessThan(25000));
  }, skip: host == null || Config.demo ? 'brak IPERF_HOST albo DEMO' : false, timeout: const Timeout(Duration(minutes: 2)));
}
