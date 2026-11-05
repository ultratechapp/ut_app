import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ut_abonent/api/api.dart';
import 'package:ut_abonent/api/models.dart';

/// Sprawdza zgodność z proxy /api/v1/klient/ (kształty jak w module /pomoc/).
void main() {
  final zapytania = <http.Request>[];
  final klient = MockClient((r) async {
    zapytania.add(r);
    final j = switch ('${r.method} ${r.url.path}') {
      'POST /api/v1/klient/logowanie' => {'token': 'eye_x', 'klient_id': 1001, 'poziom': 1, 'wygasa': '2030-01-01T00:00:00Z'},
      'GET /api/v1/klient/stan' => {'stan': 'zle', 'opis': 'ONU nie odpowiada.', 'internet': false, 'onu_online': false, 'restart_mozliwy': true},
      'GET /api/v1/klient/poziom' => {'poziom': 1, 'ujemne_saldo': true},
      'GET /api/v1/klient/wylaczenia-pradu' => {'wylaczenia': [{'od': '2026-11-05 9:00', 'do': '14:00'}]},
      'GET /api/v1/klient/awarie' => {'awarie': [{'id': 90001, 'zgloszono': '2026-11-04 10:00:00', 'otwarta': true, 'opis': 'x'}]},
      'POST /api/v1/klient/sms/kod' => {'ok': true},
      'POST /api/v1/klient/diagnoza' => {'id': 77},
      'POST /api/v1/klient/obciazenie/start' => {'id': 'a1b2c3d4e5f60718', 'czas_trwania_s': 25},
      'POST /api/v1/klient/obciazenie/a1b2c3d4e5f60718/wynik' => {'ok': true},
      'GET /api/v1/klient/obciazenie/a1b2c3d4e5f60718' => {
          'koniec': true,
          'odcinki': [
            {'kod': 'lacze_ut', 'nazwa': 'Łącze UltraTech do Twojego routera', 'stan': 'ok'},
            {'kod': 'router_wifi', 'nazwa': 'Twój router i Wi-Fi do tego urządzenia', 'stan': 'blad'},
          ],
          'proponuj_test_kabel': true,
        },
      'GET /api/v1/klient/diagnoza/77' => {
          'koniec': false,
          'kroki': [
            {'kod': 'onu', 'nazwa': 'ONU', 'stan': 'ok'},
            {'kod': 'lan', 'nazwa': 'LAN', 'stan': 'trwa'},
          ],
          'lan': {'link': true, 'predkosc': '1000 Mb/s', 'ruch': false},
          'dostep_warunkowy': false,
        },
      'GET /api/v1/klient/dostep-warunkowy' => {'mozliwy': false, 'nastepny_od': '2027-01-01', 'dni': 3, 'aktywny': false},
      _ => null,
    };
    if (r.url.path.endsWith('/awarie') && r.method == 'POST') {
      return http.Response.bytes(utf8.encode(jsonEncode({'blad': 'Potwierdź numer telefonu kodem SMS.', 'wymagany_poziom': 3})), 403);
    }
    return j == null ? http.Response('', 404) : http.Response.bytes(utf8.encode(jsonEncode(j)), 200);
  });
  final api = HttpApi('https://ultratech.net.pl/api/v1', client: klient);

  test('logowanie ID + PIN', () async {
    final s = await api.zaloguj('1001', '1234');
    expect(s.token, 'eye_x');
    expect(s.poziom, 1);
    final body = jsonDecode(zapytania.last.body);
    expect(body['id'], '1001');
    expect(body['aplikacja'], 'klienci');
  });

  test('stan łączy stan, poziom i wyłączenia prądu', () async {
    final s = await api.stan('eye_x');
    expect(s.ocena, 'zle');
    expect(s.onuOnline, false);
    expect(s.wstrzymana, true);
    expect(s.restartOnuMozliwy, true);
    expect(s.wylaczeniePradu, '2026-11-05 9:00 – 14:00');
    expect(zapytania.last.headers['Authorization'], 'Bearer eye_x');
  });

  test('lista zgłoszeń', () async {
    final l = await api.mojeZgloszenia('eye_x');
    expect(l.single.numer, 'A90001');
    expect(l.single.status, 'w realizacji');
  });

  test('kod SMS poziomu 3', () async {
    await api.wyslijKodSms('eye_x', '600100200', 'rozszerzony');
    expect(jsonDecode(zapytania.last.body), {'tel': '600100200', 'poziom': 3});
  });

  test('diagnoza krok po kroku i LAN', () async {
    final id = await api.startDiagnozy('eye_x');
    expect(id, '77');
    final d = await api.krokDiagnozy('eye_x', id);
    expect(d.koniec, false);
    expect(d.postep, 0.5);
    expect(d.lan!.ruch, false);
  });

  test('dostęp warunkowy: stan', () async {
    final dw = await api.dostepWarunkowy('eye_x');
    expect(dw.mozliwy, false);
    expect(dw.nastepnyOd, '2027-01-01');
  });

  test('test pod obciążeniem: start, wynik, werdykty', () async {
    final id = await api.obciazenieStart('eye_x');
    expect(id, 'a1b2c3d4e5f60718');
    await api.obciazenieWynik('eye_x', id, {'okna': {'pobieranie': [3600, 11500]}});
    expect(jsonDecode(zapytania.last.body)['okna']['pobieranie'], [3600, 11500]);
    final o = await api.obciazenieStan('eye_x', id);
    expect(o.koniec, true);
    expect(o.odcinki.last.stan, 'blad');
    expect(o.proponujTestKabel, true);
  });

  test('403 z wymagany_poziom', () async {
    await expectLater(
        api.wyslijZgloszenie('eye_x', {'opis': 'x'}),
        throwsA(isA<BladApi>()
            .having((e) => e.wymaganyPoziom, 'poziom', 3)
            .having((e) => e.komunikat, 'tekst', contains('SMS'))));
  });
}
