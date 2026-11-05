import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

/// Klient protokołu iperf3 (TCP) w czystym Darcie: działa na Androidzie, iPhonie i komputerze
/// bez dołączania programu iperf3. Serwer: kontener iperf3 na CCR2216 (port 5201) z uwierzytelnieniem RSA
/// (`--rsa-private-key-path`, `--authorized-users-path`). Przeglądarka tego nie użyje (brak gniazd TCP).
///
/// Protokół jak w iperf 3.x: połączenie sterujące z „cookie”, wymiana parametrów JSON, strumienie danych,
/// TEST_END, wymiana wyników JSON. Pierwsze [omit] sekund jest pomijane po obu stronach (boost łącza).
class Iperf3 {
  // Stany protokołu (iperf_api.h)
  static const testStart = 1, testRunning = 2, testEnd = 4, paramExchange = 9, createStreams = 10;
  static const serverTerminate = 11, exchangeResults = 13, displayResults = 14, iperfDone = 16;
  static const accessDenied = -1, serverError = -2;

  final String host;
  final int port;
  final String? uzytkownik;
  final String? haslo;
  final String? kluczPublicznyPem;

  /// iperf3 >= 3.17 domyślnie szyfruje token OAEP; starsze (np. 3.16) i `--use-pkcs1-padding` używają PKCS#1 v1.5.
  final bool pkcs1;

  Iperf3({required this.host, this.port = 5201, this.uzytkownik, this.haslo, this.kluczPublicznyPem, this.pkcs1 = true});

  /// Jeden pomiar. [pobieranie] = tryb odwrotny (-R): serwer wysyła, telefon odbiera.
  /// [postep] dostaje co ok. 250 ms (Mb/s z ostatniego odcinka, sekundy od startu).
  Future<WynikIperf> zmierz({
    required bool pobieranie,
    int czas = 8,
    int omit = 3,
    int strumienie = 4,
    void Function(double mbps, double sekundy)? postep,
    bool Function()? przerwij,
  }) async {
    final cookie = _cookie();
    final ster = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
    ster.setOption(SocketOption.tcpNoDelay, true);
    final we = _Czytnik(ster);
    final dane = <Socket>[];
    try {
      ster.add(cookie);
      await ster.flush();

      var stan = await we.bajtStanu();
      if (stan == accessDenied) throw const IperfBlad('Serwer testu odmówił dostępu (zajęty albo złe dane logowania).');
      if (stan != paramExchange) throw IperfBlad('Nieoczekiwana odpowiedź serwera testu ($stan).');

      final param = <String, dynamic>{
        'tcp': true,
        'omit': omit,
        'time': czas,
        'num': 0,
        'blockcount': 0,
        'parallel': strumienie,
        'len': 128 * 1024,
        'pacing_timer': 1000,
        'client_version': '3.16',
        if (pobieranie) 'reverse': true,
        if (uzytkownik != null && haslo != null && kluczPublicznyPem != null)
          'authtoken': tokenUwierzytelnienia(uzytkownik!, haslo!, kluczPublicznyPem!, pkcs1: pkcs1),
      };
      _wyslijJson(ster, param);
      await ster.flush();

      // Strumienie danych
      var bajty = 0; // tylko po okresie omit
      var bajtyWszystkie = 0;
      final zegar = Stopwatch();
      var koniec = false;
      final blok = Uint8List(128 * 1024);
      final zadania = <Future<void>>[];
      WynikIperf? wynik;

      while (true) {
        stan = await we.bajtStanu();
        if (stan == createStreams) {
          for (var i = 0; i < strumienie; i++) {
            final s = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
            s.add(cookie);
            await s.flush();
            dane.add(s);
          }
        } else if (stan == testStart) {
          // nic: czekamy na TEST_RUNNING
        } else if (stan == testRunning) {
          zegar.start();
          for (final s in dane) {
            if (pobieranie) {
              final c = Completer<void>();
              s.listen((d) {
                bajtyWszystkie += d.length;
                if (zegar.elapsedMilliseconds >= omit * 1000) bajty += d.length;
              }, onDone: () => c.isCompleted ? null : c.complete(), onError: (_) => c.isCompleted ? null : c.complete(), cancelOnError: true);
              zadania.add(c.future);
            } else {
              zadania.add(() async {
                try {
                  var n = 0;
                  while (!koniec) {
                    s.add(blok);
                    await s.flush();
                    bajtyWszystkie += blok.length;
                    if (zegar.elapsedMilliseconds >= omit * 1000) bajty += blok.length;
                    // przy szybkim łączu flush kończy się od razu: oddajemy pętlę zdarzeń zegarowi testu
                    if (++n % 8 == 0) await Future<void>(() {});
                  }
                } catch (_) {}
              }());
            }
          }
          // Odliczanie testu po stronie klienta
          var poprzednie = 0, poprzedniMs = 0;
          final predkosci = <double>[];
          while (zegar.elapsedMilliseconds < (czas + omit) * 1000) {
            if (przerwij?.call() == true) break;
            await Future.delayed(const Duration(milliseconds: 250));
            final ms = zegar.elapsedMilliseconds;
            final chwilowa = (bajtyWszystkie - poprzednie) * 8 / ((ms - poprzedniMs) / 1000) / 1e6;
            poprzednie = bajtyWszystkie;
            poprzedniMs = ms;
            if (ms >= omit * 1000) predkosci.add(chwilowa);
            postep?.call(predkosci.isEmpty ? 0 : _mediana(predkosci), ms / 1000);
          }
          koniec = true;
          ster.add([testEnd]);
          await ster.flush();
        } else if (stan == exchangeResults) {
          final sek = max(0.001, (zegar.elapsedMilliseconds / 1000) - omit);
          final wyniki = {
            'cpu_util_total': 0,
            'cpu_util_user': 0,
            'cpu_util_system': 0,
            'sender_has_retransmits': pobieranie ? 0 : -1,
            'streams': [
              for (var i = 0; i < dane.length; i++)
                {
                  'id': i == 0 ? 1 : i + 2,
                  'bytes': bajty ~/ dane.length,
                  'retransmits': -1,
                  'jitter': 0,
                  'errors': 0,
                  'omitted_errors': 0,
                  'packets': 0,
                  'omitted_packets': 0,
                  'start_time': 0,
                  'end_time': sek,
                }
            ],
          };
          _wyslijJson(ster, wyniki);
          await ster.flush();
          final odSerwera = await we.json();
          final mbpsKlient = bajty * 8 / sek / 1e6;
          // Serwer jako nadawca przy pobieraniu podaje retransmisje TCP – przydatne w raporcie.
          final strumienieSerwera = (odSerwera['streams'] as List?) ?? const [];
          final retr = strumienieSerwera.fold<int>(0, (a, e) => a + ((e as Map)['retransmits'] as int? ?? 0));
          final bajtySerwera = strumienieSerwera.fold<int>(0, (a, e) => a + ((e as Map)['bytes'] as int? ?? 0));
          wynik = WynikIperf(
            mbps: mbpsKlient,
            mbpsSerwer: bajtySerwera * 8 / sek / 1e6,
            retransmisje: pobieranie ? retr : null,
            sekundy: sek,
          );
        } else if (stan == displayResults) {
          ster.add([iperfDone]);
          await ster.flush();
          if (wynik != null) return wynik;
          throw const IperfBlad('Serwer testu nie przesłał wyników.');
        } else if (stan == serverTerminate || stan == serverError || stan == accessDenied) {
          throw IperfBlad('Serwer testu przerwał pomiar ($stan).');
        }
      }
    } finally {
      for (final s in dane) {
        s.destroy();
      }
      try {
        await ster.close();
      } catch (_) {}
      ster.destroy();
    }
  }

  static double _mediana(List<double> l) {
    final s = List.of(l)..sort();
    return s[s.length ~/ 2];
  }

  static Uint8List _cookie() {
    const znaki = 'abcdefghijklmnopqrstuvwxyz234567';
    final r = Random.secure();
    return Uint8List.fromList([...List.generate(36, (_) => znaki.codeUnitAt(r.nextInt(znaki.length))), 0]);
  }

  static void _wyslijJson(Socket s, Map<String, dynamic> j) {
    final b = utf8.encode(jsonEncode(j));
    final dl = ByteData(4)..setUint32(0, b.length);
    s.add(dl.buffer.asUint8List());
    s.add(b);
  }

  /// Token jak w iperf_auth.c: RSA(public) z tekstu "user: U\npwd:  P\nts:   T", zakodowany base64.
  /// Serwer akceptuje znacznik czasu z rozrzutem do 10 s, więc zegar urządzenia musi być ustawiony.
  static String tokenUwierzytelnienia(String uzytkownik, String haslo, String pem, {bool pkcs1 = true, int? ts}) {
    final t = ts ?? DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final tekst = utf8.encode('user: $uzytkownik\npwd:  $haslo\nts:   $t');
    final klucz = kluczPublicznyZPem(pem);
    final AsymmetricBlockCipher szyfr = pkcs1 ? PKCS1Encoding(RSAEngine()) : OAEPEncoding(RSAEngine());
    final los = FortunaRandom()..seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)))));
    szyfr.init(true, ParametersWithRandom(PublicKeyParameter<RSAPublicKey>(klucz), los));
    return base64.encode(szyfr.process(Uint8List.fromList(tekst)));
  }

  /// PEM "BEGIN PUBLIC KEY" (SubjectPublicKeyInfo) albo "BEGIN RSA PUBLIC KEY" (PKCS#1).
  static RSAPublicKey kluczPublicznyZPem(String pem) {
    if (!pem.contains('-----')) pem = '-----BEGIN PUBLIC KEY-----\n$pem\n-----END PUBLIC KEY-----';
    final rsaPkcs1 = pem.contains('BEGIN RSA PUBLIC KEY');
    final der = base64.decode(pem.split('\n').where((l) => !l.startsWith('-----')).join().trim());
    var seq = ASN1Parser(Uint8List.fromList(der)).nextObject() as ASN1Sequence;
    if (!rsaPkcs1) {
      final bitString = seq.elements![1] as ASN1BitString;
      seq = ASN1Parser(Uint8List.fromList(bitString.stringValues!)).nextObject() as ASN1Sequence;
    }
    final n = (seq.elements![0] as ASN1Integer).integer!;
    final e = (seq.elements![1] as ASN1Integer).integer!;
    return RSAPublicKey(n, e);
  }
}

class WynikIperf {
  final double mbps; // zmierzone u klienta, po okresie omit
  final double mbpsSerwer; // według serwera
  final int? retransmisje; // TCP po stronie serwera (pobieranie)
  final double sekundy;
  WynikIperf({required this.mbps, required this.mbpsSerwer, this.retransmisje, required this.sekundy});
}

class IperfBlad implements Exception {
  final String komunikat;
  const IperfBlad(this.komunikat);
  @override
  String toString() => komunikat;
}

/// Czytanie bajtów stanu i bloków JSON z połączenia sterującego.
class _Czytnik {
  final _bufor = <int>[];
  final _czekajacy = <Completer<void>>[];
  bool _koniec = false;

  _Czytnik(Socket s) {
    s.listen((d) {
      _bufor.addAll(d);
      _obudz();
    }, onDone: () {
      _koniec = true;
      _obudz();
    }, onError: (_) {
      _koniec = true;
      _obudz();
    });
  }

  void _obudz() {
    for (final c in _czekajacy) {
      if (!c.isCompleted) c.complete();
    }
    _czekajacy.clear();
  }

  Future<List<int>> _wez(int n) async {
    while (_bufor.length < n) {
      if (_koniec) throw const IperfBlad('Serwer testu zamknął połączenie.');
      final c = Completer<void>();
      _czekajacy.add(c);
      await c.future.timeout(const Duration(seconds: 30), onTimeout: () => throw const IperfBlad('Serwer testu nie odpowiada.'));
    }
    final w = _bufor.sublist(0, n);
    _bufor.removeRange(0, n);
    return w;
  }

  Future<int> bajtStanu() async {
    final b = (await _wez(1))[0];
    return b > 127 ? b - 256 : b; // signed char
  }

  Future<Map<String, dynamic>> json() async {
    final dl = ByteData.sublistView(Uint8List.fromList(await _wez(4))).getUint32(0);
    return jsonDecode(utf8.decode(await _wez(dl))) as Map<String, dynamic>;
  }
}
