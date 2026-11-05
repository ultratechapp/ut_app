import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/models.dart';
import '../config.dart';
import 'iperf3.dart';

enum Faza { ping, pobieranie, wysylanie, koniec }

class PostepTestu {
  final Faza faza;
  final double wartosc; // Mb/s albo ms
  final double postep; // 0..1 całego testu
  PostepTestu(this.faza, this.wartosc, this.postep);
}

/// Okna pomiaru (ms od [TestPredkosci.t0]) bez boostu: te same okna EYE bierze do liczników ONU.
class OknaPomiaru {
  (int, int)? pobieranie;
  (int, int)? wysylanie;
  Map<String, dynamic> toJson() => {
        if (pobieranie != null) 'pobieranie': [pobieranie!.$1, pobieranie!.$2],
        if (wysylanie != null) 'wysylanie': [wysylanie!.$1, wysylanie!.$2],
      };
}

double mediana(List<double> l) => percentyl(l, 50);

double percentyl(List<double> l, double p) {
  if (l.isEmpty) return 0;
  final s = List.of(l)..sort();
  final i = ((p / 100) * (s.length - 1));
  final d = i.floor(), g = i.ceil();
  return s[d] + (s[g] - s[d]) * (i - d);
}

/// Test prędkości z urządzenia do serwera w sieci UT, protokół LibreSpeed
/// (backend: empty.php, garbage.php).
///
/// Test pod obciążeniem (decyzja z 05.11.2026):
/// - w trakcie pobierania i wysyłania co 250 ms próbka opóźnienia na OSOBNYM połączeniu
///   (timeout 2 s = próbka bez odpowiedzi),
/// - boost: pierwsze [pominBoost] każdej fazy nie liczy się do wyniku; prędkość to mediana
///   z próbek co 250 ms w pozostałej części fazy,
/// - okna bez boostu (ms od [t0]) zapisujemy w [okna], żeby EYE liczył liczniki ONU w tym samym czasie.
class TestPredkosci {
  final String url;
  final http.Client Function() _klient;
  final Duration czasFazy;
  final Duration pominBoost;
  final int strumienie;

  /// Serwery iperf3 (po jednym na port). null = pomiar przez HTTP (przeglądarka albo brak konfiguracji).
  final List<Iperf3>? iperf;
  bool _przerwij = false;
  String _metoda = 'http';
  int? _retransmisje;

  /// Chwila odniesienia dla okien (odpowiedź EYE na start pomiaru albo start testu).
  DateTime t0 = DateTime.now();
  final okna = OknaPomiaru();
  final _probkiPob = <double>[];
  final _probkiWys = <double>[];
  int _bezOdp = 0, _wszystkie = 0;

  TestPredkosci({
    String? url,
    http.Client Function()? klient,
    this.czasFazy = const Duration(milliseconds: 11500), // obie fazy mieszczą się w 25 s okna EYE
    this.pominBoost = const Duration(milliseconds: 3500),
    this.strumienie = 4,
    List<Iperf3>? iperf,
  })  : url = url ?? Config.speedtestUrl,
        _klient = klient ?? http.Client.new,
        iperf = iperf ?? iperfZKonfiguracji();

  /// iperf3 tylko w aplikacji (telefon, komputer). W przeglądarce nie ma gniazd TCP.
  static List<Iperf3>? iperfZKonfiguracji() {
    if (kIsWeb || Config.iperfHost.isEmpty || Config.portyIperf.isEmpty) return null;
    // bez hasła lub klucza serwer z RSA i tak odmówi: od razu HTTP
    if (Config.iperfUzytkownik.isNotEmpty && (Config.iperfHaslo.isEmpty || Config.iperfKlucz.isEmpty)) return null;
    return [
      for (final p in Config.portyIperf)
        Iperf3(
          host: Config.iperfHost,
          port: p,
          uzytkownik: Config.iperfUzytkownik.isEmpty ? null : Config.iperfUzytkownik,
          haslo: Config.iperfHaslo.isEmpty ? null : Config.iperfHaslo,
          kluczPublicznyPem: Config.iperfKlucz.isEmpty ? null : Config.iperfKlucz,
          pkcs1: Config.iperfPkcs1,
        ),
    ];
  }

  void przerwij() => _przerwij = true;
  int _ms() => DateTime.now().difference(t0).inMilliseconds;

  /// [startObciazenia] jest wołane tuż przed fazą pobierania (po pomiarze w spoczynku):
  /// zwraca id pomiaru EYE albo null; od tej chwili liczą się okna [okna].
  Stream<PostepTestu> uruchom({
    required String polaczenie,
    Polaczenie? siec,
    Future<String?> Function()? startObciazenia,
    void Function(WynikTestu)? gotowe,
  }) async* {
    _przerwij = false;
    String? idObciazenia;
    Future<void> start() async {
      try {
        idObciazenia = await startObciazenia?.call();
      } catch (_) {
        idObciazenia = null; // test prędkości działa także bez EYE
      }
      t0 = DateTime.now();
    }

    // W trybie pokazowym z podanym IPERF_HOST mierzymy naprawdę (próba iperf3 w sieci klienta).
    if (Config.demo && iperf == null) {
      yield* _demo(polaczenie, siec, start, () => idObciazenia, gotowe);
      return;
    }
    // 1. Opóźnienie w spoczynku: 10 krótkich zapytań
    final c = _klient();
    final czasy = <double>[];
    for (var i = 0; i < 10 && !_przerwij; i++) {
      final sw = Stopwatch()..start();
      final r = await c
          .get(Uri.parse('$url/empty.php?r=${Random().nextDouble()}'), headers: {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 5));
      sw.stop();
      if (r.statusCode >= 400) throw Exception('Serwer testu zwrócił błąd ${r.statusCode}');
      if (i > 0) czasy.add(sw.elapsedMicroseconds / 1000); // pierwsze zapytanie zestawia połączenie
      yield PostepTestu(Faza.ping, czasy.isEmpty ? 0 : mediana(czasy), 0.08 * (i + 1) / 10);
    }
    c.close();
    final ping = mediana(czasy);
    var jitter = 0.0;
    for (var i = 1; i < czasy.length; i++) {
      jitter += (czasy[i] - czasy[i - 1]).abs();
    }
    if (czasy.length > 1) jitter /= (czasy.length - 1);

    // 2. Pobieranie, 3. Wysyłanie (z próbkami opóźnienia pod obciążeniem)
    await start();
    double pob = 0, wys = 0;
    await for (final v in _faza(pobieranie: true)) {
      pob = v.$1;
      yield PostepTestu(Faza.pobieranie, pob, 0.08 + 0.46 * v.$2);
    }
    await for (final v in _faza(pobieranie: false)) {
      wys = v.$1;
      yield PostepTestu(Faza.wysylanie, wys, 0.54 + 0.46 * v.$2);
    }
    final w = WynikTestu(
      pobieranieMbps: pob,
      wysylanieMbps: wys,
      pingMs: ping,
      jitterMs: jitter,
      polaczenie: polaczenie,
      kiedy: DateTime.now(),
      opoznienie: _opoznienie(ping, jitter),
      siec: siec,
      idObciazenia: idObciazenia,
      metoda: _metoda,
      retransmisje: _retransmisje,
    );
    gotowe?.call(w);
    yield PostepTestu(Faza.koniec, 0, 1);
  }

  Opoznienie _opoznienie(double ping, double jitter) => Opoznienie(
        spoczynekMs: ping,
        pobMedMs: mediana(_probkiPob),
        pobP90Ms: percentyl(_probkiPob, 90),
        wysMedMs: mediana(_probkiWys),
        wysP90Ms: percentyl(_probkiWys, 90),
        jitterMs: jitter,
        bezOdpProc: _wszystkie == 0 ? 0 : 100 * _bezOdp / _wszystkie,
      );

  /// Próbki opóźnienia co 250 ms na osobnym kliencie HTTP, dopóki [trwa] zwraca true.
  Future<void> _probkujOpoznienie(List<double> cel, bool Function() trwa) async {
    final c = _klient();
    try {
      while (trwa()) {
        final start = DateTime.now();
        final sw = Stopwatch()..start();
        _wszystkie++;
        try {
          await c
              .get(Uri.parse('$url/empty.php?p=${Random().nextDouble()}'), headers: {'Cache-Control': 'no-cache'})
              .timeout(const Duration(seconds: 2));
          cel.add(sw.elapsedMicroseconds / 1000);
        } catch (_) {
          _bezOdp++;
        }
        final reszta = 250 - DateTime.now().difference(start).inMilliseconds;
        if (reszta > 0) await Future.delayed(Duration(milliseconds: reszta));
      }
    } finally {
      c.close();
    }
  }

  /// Faza przez iperf3, a gdy serwer jest zajęty albo nieosiągalny – przez HTTP.
  Stream<(double, double)> _faza({required bool pobieranie}) async* {
    if (iperf != null && iperf!.isNotEmpty) {
      try {
        await for (final w in _iperfFaza(pobieranie: pobieranie)) {
          yield w;
        }
        return;
      } catch (_) {
        // serwer iperf3 zajęty, nieosiągalny albo pomiar się urwał: ta faza przez HTTP
      }
    }
    yield* _pomiar(pobieranie: pobieranie);
  }

  /// Pomiar iperf3 na losowo wybranym wolnym porcie. Okno bez boostu = od końca okresu omit do końca pomiaru.
  /// Próbki opóźnienia HTTP idą równolegle, tak jak przy teście HTTP.
  Stream<(double, double)> _iperfFaza({required bool pobieranie}) {
    final wy = StreamController<(double, double)>();
    final czas = ((czasFazy - pominBoost).inMilliseconds / 1000).round();
    final omit = (pominBoost.inMilliseconds / 1000).ceil();
    () async {
      final porty = List.of(iperf!)..shuffle();
      var koniec = false;
      final probkowanie = _probkujOpoznienie(pobieranie ? _probkiPob : _probkiWys, () => !koniec && !_przerwij);
      try {
        for (final serwer in porty) {
          int? oknoOd;
          try {
            final start = _ms();
            final w = await serwer.zmierz(
              pobieranie: pobieranie,
              czas: czas,
              omit: omit,
              strumienie: strumienie,
              przerwij: () => _przerwij,
              postep: (mbps, sek) {
                if (sek >= omit) oknoOd ??= start + omit * 1000;
                wy.add((mbps, sek / (czas + omit)));
              },
            );
            final oknoDo = _ms();
            final o = (oknoOd ?? start + omit * 1000, oknoDo);
            if (pobieranie) {
              okna.pobieranie = o;
              _retransmisje = w.retransmisje;
            } else {
              okna.wysylanie = o;
            }
            _metoda = 'iperf3';
            wy.add((w.mbps, 1));
            return;
          } catch (_) {
            // zajęty port albo brak połączenia: następny port; pomiar ruszył i się urwał: nie powtarzamy
            if (oknoOd != null) rethrow;
          }
        }
        throw const IperfBlad('Brak wolnego serwera iperf3.');
      } finally {
        koniec = true;
        await probkowanie.timeout(const Duration(seconds: 3), onTimeout: () {});
      }
    }()
        .then((_) => wy.close(), onError: (Object e) {
      wy.addError(e);
      wy.close();
    });
    return wy.stream;
  }

  /// Zwraca (Mb/s ustalone, postęp fazy 0..1) co 250 ms.
  Stream<(double, double)> _pomiar({required bool pobieranie}) async* {
    var bajty = 0;
    final sw = Stopwatch()..start();
    var koniec = false;
    final klienci = List.generate(strumienie, (_) => _klient());
    final blob = pobieranie ? null : Uint8List.fromList(List.generate(1 << 20, (i) => (i * 31) & 0xff));

    Future<void> strumien(http.Client c) async {
      while (!koniec && !_przerwij) {
        try {
          if (pobieranie) {
            final req = http.Request('GET', Uri.parse('$url/garbage.php?ckSize=20&r=${Random().nextDouble()}'));
            final odp = await c.send(req);
            await for (final kawalek in odp.stream) {
              bajty += kawalek.length;
              if (koniec || _przerwij) break;
            }
          } else {
            await c.post(Uri.parse('$url/empty.php?r=${Random().nextDouble()}'), body: blob);
            if (!koniec) bajty += blob!.length;
          }
        } catch (_) {
          if (koniec || _przerwij) return;
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
    }

    final zadania = klienci.map(strumien).toList();
    final probkowanie = _probkujOpoznienie(pobieranie ? _probkiPob : _probkiWys, () => !koniec && !_przerwij);
    final predkosci = <double>[];
    var poprzednieBajty = 0, poprzedniMs = 0;
    int? oknoOd;
    var wynik = 0.0;
    while (sw.elapsed < czasFazy && !_przerwij) {
      await Future.delayed(const Duration(milliseconds: 250));
      final ms = sw.elapsedMilliseconds;
      final chwilowa = (bajty - poprzednieBajty) * 8 / ((ms - poprzedniMs) / 1000) / 1e6;
      poprzednieBajty = bajty;
      poprzedniMs = ms;
      if (ms >= pominBoost.inMilliseconds) {
        oknoOd ??= _ms();
        predkosci.add(chwilowa);
        wynik = mediana(predkosci);
      }
      yield (wynik, ms / czasFazy.inMilliseconds);
    }
    final oknoDo = _ms();
    if (oknoOd != null) {
      if (pobieranie) {
        okna.pobieranie = (oknoOd, oknoDo);
      } else {
        okna.wysylanie = (oknoOd, oknoDo);
      }
    }
    koniec = true;
    for (final c in klienci) {
      c.close();
    }
    await Future.wait([...zadania, probkowanie]).timeout(const Duration(seconds: 3), onTimeout: () => []);
  }

  Stream<PostepTestu> _demo(String polaczenie, Polaczenie? siec, Future<void> Function() start, String? Function() idObciazenia,
      void Function(WynikTestu)? gotowe) async* {
    final r = Random();
    for (var i = 0; i <= 10 && !_przerwij; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      yield PostepTestu(Faza.ping, 6 + r.nextDouble() * 3, 0.08 * i / 10);
    }
    await start();
    // na początku boost ok. 1 Gb/s, potem ustalone ok. 800 / 300 Mb/s (kabel) albo mniej (Wi-Fi)
    final wifi = polaczenie == 'wifi';
    final docPob = wifi ? 310.0 : 805.0, docWys = wifi ? 150.0 : 302.0;
    for (var i = 0; i <= 25 && !_przerwij; i++) {
      await Future.delayed(const Duration(milliseconds: 110));
      yield PostepTestu(Faza.pobieranie, i < 7 ? 0 : docPob + r.nextDouble() * 8, 0.08 + 0.46 * i / 25);
    }
    for (var i = 0; i <= 25 && !_przerwij; i++) {
      await Future.delayed(const Duration(milliseconds: 110));
      yield PostepTestu(Faza.wysylanie, i < 7 ? 0 : docWys + r.nextDouble() * 5, 0.54 + 0.46 * i / 25);
    }
    okna
      ..pobieranie = (4600, 12000)
      ..wysylanie = (16600, 24000);
    gotowe?.call(WynikTestu(
      pobieranieMbps: docPob,
      wysylanieMbps: docWys,
      pingMs: 7,
      jitterMs: 1,
      polaczenie: polaczenie,
      kiedy: DateTime.now(),
      opoznienie: Opoznienie(
          spoczynekMs: 7,
          pobMedMs: wifi ? 180 : 14,
          pobP90Ms: wifi ? 260 : 19,
          wysMedMs: wifi ? 140 : 12,
          wysP90Ms: wifi ? 210 : 16,
          jitterMs: 1,
          bezOdpProc: wifi ? 3 : 0),
      siec: siec,
      idObciazenia: idObciazenia(),
    ));
    yield PostepTestu(Faza.koniec, 0, 1);
  }

  @visibleForTesting
  List<double> get probkiPobierania => _probkiPob;
}
