import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Dostępność polskich serwisów z urządzenia klienta (decyzja Ja z 05.11.2026):
/// klientowi pokazujemy tylko werdykt OK / nie OK, a dokładne czasy idą wyłącznie
/// w zgłoszeniu do EYE (pole `ranking`). Pokazywanie pingów do obcych serwerów kończy się
/// sporami, bo serwisy mają DDoS albo wyłączają ICMP. OK = odpowiada co najmniej 10 z 30.
/// Ta sama lista co w /pomoc/ (lib/konfig.php 'ranking') i w EYE (DiagnozaKlienta::POLSKA).
class RankingSerwisow {
  static const hosty = [
    'www.onet.pl', 'www.wp.pl', 'www.interia.pl', 'allegro.pl', 'www.olx.pl', 'www.gov.pl', 'www.mbank.pl', 'www.pkobp.pl',
    'www.ing.pl', 'www.santander.pl', 'www.ceneo.pl', 'www.gazeta.pl', 'tvn24.pl', 'www.polsatnews.pl', 'www.money.pl',
    'www.x-kom.pl', 'www.empik.com', 'www.cda.pl', 'www.player.pl', 'vod.tvp.pl', 'www.rmf.fm', 'www.mediaexpert.pl',
    'www.euro.com.pl', 'www.morele.net', 'www.pracuj.pl', 'www.otomoto.pl', 'inpost.pl', 'www.poczta-polska.pl',
    'www.wykop.pl', 'www.nazwa.pl',
  ];
  static const minSerwisow = 10;

  /// Czas odpowiedzi HTTPS (ms) albo null przy braku odpowiedzi. W przeglądarce pomijamy
  /// (CORS), tam ranking robi EYE z terminala klienta.
  static Future<List<({String host, int? ms})>?> zmierz({http.Client Function()? klient, bool demo = false}) async {
    if (kIsWeb) return null;
    if (demo) {
      return [for (var i = 0; i < hosty.length; i++) (host: hosty[i], ms: i % 9 == 4 ? null : 12 + (i * 7) % 40)];
    }
    final c = (klient ?? http.Client.new)();
    try {
      final wyniki = <({String host, int? ms})>[];
      for (var i = 0; i < hosty.length; i += 10) {
        wyniki.addAll(await Future.wait(hosty.skip(i).take(10).map((h) async {
          final sw = Stopwatch()..start();
          try {
            await c.head(Uri.parse('https://$h/')).timeout(const Duration(seconds: 4));
            return (host: h, ms: sw.elapsedMilliseconds);
          } catch (_) {
            return (host: h, ms: null);
          }
        })));
      }
      return wyniki;
    } finally {
      c.close();
    }
  }

  static bool ok(List<({String host, int? ms})> r) => r.where((e) => e.ms != null).length >= minSerwisow;

  static List<Map<String, dynamic>> doZgloszenia(List<({String host, int? ms})> r) =>
      [for (final e in r) {'host': e.host, 'ms': e.ms}];
}
