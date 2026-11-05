import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'models.dart';

/// Jedno miejsce, przez które aplikacja rozmawia z EYE.
/// [HttpApi] łączy się z prawdziwym API, [DemoApi] zwraca dane przykładowe.
abstract class Api {
  // Komunikaty (ekran główny)
  Future<List<Komunikat>> komunikaty({String? token});

  // Poziom 1: ID klienta z net47 + PIN e-BOK
  Future<Sesja> zaloguj(String idKlienta, String pin);
  Future<void> wyloguj(String token);

  // Poziom 2 i 3: kod SMS. cel = 'zgloszenie' (dowolny numer) albo 'rozszerzony'
  // (numer z net47 wpisany przez klienta, bez podpowiedzi).
  Future<void> wyslijKodSms(String token, String telefon, String cel);
  Future<Sesja> potwierdzKodSms(Sesja sesja, String kod);

  // Diagnoza i zgłoszenia
  Future<StanLacza> stan(String token, {String? przylacze});
  Future<List<Zgloszenie>> mojeZgloszenia(String token);
  Future<String> wyslijZgloszenie(String token, Map<String, dynamic> dane);
  Future<String> restartOnu(String token, {String? przylacze});

  // Diagnoza krok po kroku (EYE: konto, onu, sesja, lan, restart_olt, internet).
  // Każde [krokDiagnozy] wykonuje w EYE jeden kolejny krok; wołać co 1–2 s, aż koniec.
  Future<String> startDiagnozy(String token, {String? przylacze});
  Future<Diagnoza> krokDiagnozy(String token, String id);

  // Test odcinków pod obciążeniem: EYE w tym samym oknie pinguje z ONU router/urządzenie i bramę
  // oraz czyta liczniki portu LAN ONU. Klient widzi tylko werdykty odcinków.
  Future<String> obciazenieStart(String token, {String? przylacze});
  Future<void> obciazenieWynik(String token, String id, Map<String, dynamic> dane);
  Future<WynikObciazenia> obciazenieStan(String token, String id);
  /// Zapis wyniku do karty klienta, gdy obciazenie/start się nie udał (np. 429). Bez werdyktu.
  Future<void> obciazenieZapis(String token, Map<String, dynamic> dane);

  // Dostęp warunkowy przy blokadzie za płatności (poziom 3 do włączenia).
  Future<DostepWarunkowy> dostepWarunkowy(String token);
  Future<String> wlaczDostepWarunkowy(String token);

  // Routery WiFi mesh (zaślepki do czasu API z projektu WiFi_openwrt)
  Future<List<RouterMesh>> routery(String token);
  Future<SiecWifi> siecWifi(String token);
  Future<void> zapiszSiecWifi(String token, {required String ssid, String? haslo, bool? gosc, String? hasloGosc});
  Future<void> restartRoutera(String token, String id);
  Future<void> aktualizujFirmware(String token, String id);
  Future<void> zmienNazweRoutera(String token, String id, String nazwa);
  Future<void> parujWezel(String token);

  static Api utworz() => Config.demo ? DemoApi() : HttpApi(Config.apiUrl);
}

class HttpApi implements Api {
  final String baseUrl;
  final http.Client _c;
  HttpApi(this.baseUrl, {http.Client? client}) : _c = client ?? http.Client();

  Map<String, String> _naglowki(String? token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Klient-Aplikacja': 'ut_abonent',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _zadanie(String metoda, String sciezka,
      {String? token, Object? body, Duration limit = const Duration(seconds: 15)}) async {
    final uri = Uri.parse('$baseUrl$sciezka');
    final req = http.Request(metoda, uri)..headers.addAll(_naglowki(token));
    if (body != null) req.body = jsonEncode(body);
    http.Response r;
    try {
      r = await http.Response.fromStream(await _c.send(req).timeout(limit));
    } catch (_) {
      throw BladApi(0, 'Brak połączenia z serwerem UltraTech. Sprawdź internet w telefonie.');
    }
    dynamic json;
    try {
      json = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      json = null;
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return json;
    final tekst = json is Map ? (json['blad'] ?? json['komunikat'] ?? json['message']) : null;
    final msg = tekst != null ? '$tekst' : _domyslnyKomunikat(r.statusCode);
    final poziom = json is Map ? int.tryParse('${json['wymagany_poziom'] ?? ''}') : null;
    throw BladApi(r.statusCode, msg, wymaganyPoziom: poziom);
  }

  String _domyslnyKomunikat(int kod) => switch (kod) {
        401 => 'Sesja wygasła. Zaloguj się ponownie.',
        403 => 'Ta operacja wymaga potwierdzenia kodem SMS.',
        409 => 'Masz już otwarte zgłoszenie. Serwis się nim zajmuje.',
        429 => 'Za dużo prób. Spróbuj ponownie za chwilę.',
        _ => 'Serwer zwrócił błąd ($kod). Spróbuj później albo zadzwoń: ${Config.telefonBiuroLadny}.',
      };

  List<dynamic> _lista(dynamic j, [String klucz = 'dane']) =>
      j is List ? j : (j is Map && j[klucz] is List ? j[klucz] : (j is Map && j['dane'] is List ? j['dane'] : []));

  /// Komunikaty z EYE; gdy EYE jest niedostępny, plik zapasowy {APP_FILES_URL}/aktualnosci.json
  /// (ten sam kształt), który można edytować ręcznie na serwerze www.
  @override
  Future<List<Komunikat>> komunikaty({String? token}) async {
    try {
      final j = await _zadanie('GET', token == null ? '/komunikaty/publiczne' : '/klient/komunikaty', token: token);
      return _lista(j, 'komunikaty').map((e) => Komunikat.fromJson(e)).toList();
    } on BladApi {
      final r = await _c.get(Uri.parse('${Config.appFilesUrl}/aktualnosci.json')).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) throw BladApi(r.statusCode, 'Nie udało się pobrać aktualności.');
      return _lista(jsonDecode(utf8.decode(r.bodyBytes)), 'komunikaty').map((e) => Komunikat.fromJson(e)).toList();
    }
  }

  @override
  Future<Sesja> zaloguj(String idKlienta, String pin) async =>
      Sesja.fromJson(await _zadanie('POST', '/klient/logowanie', body: {
        'id': idKlienta,
        'pin': pin,
        // www = token na 2 h (panel w przeglądarce), klienci = aplikacja mobilna
        'aplikacja': kIsWeb ? 'www' : 'klienci',
      }));

  @override
  Future<void> wyloguj(String token) async {
    try {
      await _zadanie('POST', '/klient/wyloguj', token: token);
    } catch (_) {}
  }

  @override
  Future<void> wyslijKodSms(String token, String telefon, String cel) =>
      _zadanie('POST', '/klient/sms/kod', token: token, body: {'tel': telefon, 'poziom': cel == 'rozszerzony' ? 3 : 2});

  @override
  Future<Sesja> potwierdzKodSms(Sesja sesja, String kod) async {
    final j = await _zadanie('POST', '/klient/sms/potwierdz', token: sesja.token, body: {'kod': kod});
    return sesja.zPoziomem(int.tryParse('${j?['poziom'] ?? 2}') ?? 2, nowyToken: j?['token'] as String?);
  }

  @override
  Future<StanLacza> stan(String token, {String? przylacze}) async {
    final q = przylacze == null ? '' : '?przylacze=$przylacze';
    Future<Map<String, dynamic>?> opcjonalnie(String sciezka) async {
      try {
        final j = await _zadanie('GET', sciezka, token: token);
        return j is Map<String, dynamic> ? j : null;
      } on BladApi catch (e) {
        if (e.kod == 401) rethrow;
        return null;
      }
    }

    final w = await Future.wait([
      _zadanie('GET', '/klient/stan$q', token: token),
      opcjonalnie('/klient/poziom'),
      opcjonalnie('/klient/wylaczenia-pradu$q'),
    ]);
    return StanLacza.fromJson(w[0] as Map<String, dynamic>,
        poziom: w[1] as Map<String, dynamic>?, wylaczenia: w[2] as Map<String, dynamic>?);
  }

  @override
  Future<List<Zgloszenie>> mojeZgloszenia(String token) async =>
      _lista(await _zadanie('GET', '/klient/awarie', token: token), 'awarie').map((e) => Zgloszenie.fromJson(e)).toList();

  @override
  Future<String> wyslijZgloszenie(String token, Map<String, dynamic> dane) async {
    final j = await _zadanie('POST', '/klient/awarie', token: token, body: dane);
    return j?['numer']?.toString() ?? (j?['id'] != null ? 'A${j['id']}' : '');
  }

  @override
  Future<String> restartOnu(String token, {String? przylacze}) async {
    final j = await _zadanie('POST', '/klient/onu/restart', token: token, body: {'przylacze': ?przylacze});
    return '${j?['komunikat'] ?? j?['message'] ?? 'Terminal zostanie uruchomiony ponownie. Poczekaj około 3 minut.'}';
  }

  @override
  Future<String> startDiagnozy(String token, {String? przylacze}) async {
    final j = await _zadanie('POST', '/klient/diagnoza', token: token, body: {'przylacze': ?przylacze});
    return '${j['id']}';
  }

  @override
  Future<Diagnoza> krokDiagnozy(String token, String id) async => Diagnoza.fromJson(
      id, await _zadanie('GET', '/klient/diagnoza/$id', token: token, limit: const Duration(seconds: 30)));

  @override
  Future<DostepWarunkowy> dostepWarunkowy(String token) async =>
      DostepWarunkowy.fromJson(await _zadanie('GET', '/klient/dostep-warunkowy', token: token));

  @override
  Future<String> wlaczDostepWarunkowy(String token) async {
    final j = await _zadanie('POST', '/klient/dostep-warunkowy', token: token);
    return '${j?['komunikat'] ?? 'Dostęp warunkowy włączony do ${j?['do'] ?? ''}.'}';
  }

  @override
  Future<String> obciazenieStart(String token, {String? przylacze}) async {
    final j = await _zadanie('POST', '/klient/obciazenie/start',
        token: token, body: {'przylacze': ?przylacze}, limit: const Duration(seconds: 40)); // telnet do ONU
    return '${j['id']}';
  }

  @override
  Future<void> obciazenieWynik(String token, String id, Map<String, dynamic> dane) =>
      _zadanie('POST', '/klient/obciazenie/$id/wynik', token: token, body: dane);

  @override
  Future<void> obciazenieZapis(String token, Map<String, dynamic> dane) =>
      _zadanie('POST', '/klient/obciazenie/zapis', token: token, body: dane);

  @override
  Future<WynikObciazenia> obciazenieStan(String token, String id) async => WynikObciazenia.fromJson(
      await _zadanie('GET', '/klient/obciazenie/$id', token: token, limit: const Duration(seconds: 30)));

  // --- Routery mesh: ścieżki uzgodnione z projektem WiFi_openwrt (do potwierdzenia) ---
  @override
  Future<List<RouterMesh>> routery(String token) async =>
      _lista(await _zadanie('GET', '/klient/routery', token: token), 'routery').map((e) => RouterMesh.fromJson(e)).toList();

  @override
  Future<SiecWifi> siecWifi(String token) async =>
      SiecWifi.fromJson(await _zadanie('GET', '/klient/routery/wifi', token: token));

  @override
  Future<void> zapiszSiecWifi(String token, {required String ssid, String? haslo, bool? gosc, String? hasloGosc}) =>
      _zadanie('PUT', '/klient/routery/wifi', token: token, body: {
        'ssid': ssid,
        'haslo': ?haslo,
        'gosc': ?gosc,
        'haslo_gosc': ?hasloGosc,
      });

  @override
  Future<void> restartRoutera(String token, String id) =>
      _zadanie('POST', '/klient/routery/$id/restart', token: token);

  @override
  Future<void> aktualizujFirmware(String token, String id) =>
      _zadanie('POST', '/klient/routery/$id/firmware', token: token);

  @override
  Future<void> zmienNazweRoutera(String token, String id, String nazwa) =>
      _zadanie('PATCH', '/klient/routery/$id', token: token, body: {'nazwa': nazwa});

  @override
  Future<void> parujWezel(String token) => _zadanie('POST', '/klient/routery/parowanie', token: token);
}

/// Dane przykładowe do pokazu i testów. PIN "1234", kod SMS "123456".
/// ID 999: dwa przyłącza, ID 1002: usługa wstrzymana (dostęp warunkowy), ID 1003: brak sesji (restart z OLT).
/// Numer "z net47" dla poziomu 3: 600100200.
class DemoApi implements Api {
  Future<void> _czekaj() => Future.delayed(const Duration(milliseconds: 500));
  String _ssid = 'UltraTech-Kowalski';
  bool _gosc = false;
  final _nazwy = <String, String>{'r1': 'Salon', 'r2': 'Piętro'};
  final List<Zgloszenie> _zgl = [
    Zgloszenie(numer: 'A10231', status: 'zamknięte', opis: 'Brak internetu po burzy', data: DateTime(2026, 9, 12)),
  ];
  int _bledneNumery = 0;
  String _id = ''; // ID 1002 = usługa wstrzymana (jak w module /pomoc/)

  @override
  Future<List<Komunikat>> komunikaty({String? token}) async {
    await _czekaj();
    final dzis = DateTime.now();
    return [
      Komunikat(
          id: '1',
          typ: 'prace_planowe',
          tytul: 'Prace serwisowe w Medyce',
          tresc: 'W nocy z 6 na 7 listopada (1:00–3:00) wymieniamy sprzęt w węźle Medyka. Możliwe przerwy do 15 minut.',
          od: DateTime(2026, 11, 7, 1),
          doKiedy: DateTime(2026, 11, 7, 3),
          priorytet: 2,
          przypiety: true,
          zaktualizowano: dzis),
      Komunikat(
          id: '2',
          typ: 'promocja',
          tytul: 'Mikołajowy Światłowód 2026',
          tresc: 'Aktywacja za 1 zł i router WiFi mesh w cenie abonamentu. Sprawdź szczegóły na stronie.',
          priorytet: 1,
          link: 'https://ultratech.net.pl/',
          zaktualizowano: dzis),
      Komunikat(
          id: '3',
          typ: 'informacja',
          tytul: 'Nowa aplikacja UltraTech',
          tresc: 'Sprawdzisz w niej stan łącza, zrobisz test prędkości i zgłosisz awarię o każdej porze.',
          zaktualizowano: dzis.subtract(const Duration(days: 2))),
      Komunikat(
          id: '4',
          typ: 'awaria',
          tytul: 'Usunięta awaria: Krasiczyn',
          tresc: 'Uszkodzony kabel został naprawiony, usługi działają normalnie. Przepraszamy za utrudnienia.',
          zaktualizowano: dzis.subtract(const Duration(days: 3))),
    ];
  }

  @override
  Future<Sesja> zaloguj(String idKlienta, String pin) async {
    await _czekaj();
    if (pin != '1234') throw BladApi(401, 'Nieprawidłowe ID klienta lub PIN.');
    _id = idKlienta;
    return Sesja(
        token: 'demo',
        poziom: 1,
        wygasa: DateTime.now().add(const Duration(hours: 2)),
        przylacza: idKlienta == '999'
            ? [Przylacze(id: 'p1', adres: 'ul. Szkolna 5, Medyka'), Przylacze(id: 'p2', adres: 'ul. Kościelna 2, Medyka')]
            : []);
  }

  @override
  Future<void> wyloguj(String token) async {}

  @override
  Future<void> wyslijKodSms(String token, String telefon, String cel) async {
    await _czekaj();
    _poziomDocelowy = cel == 'rozszerzony' ? 3 : 2;
    if (cel == 'rozszerzony' && telefon.replaceAll(RegExp(r'\D'), '') != '600100200') {
      _bledneNumery++;
      if (_bledneNumery >= 3) throw BladApi(429, 'Za dużo błędnych numerów. Spróbuj za godzinę.');
      throw BladApi(403, 'Ten numer nie jest przypisany do konta. Zadzwoń do biura: ${Config.telefonBiuroLadny}.');
    }
  }

  @override
  Future<Sesja> potwierdzKodSms(Sesja sesja, String kod) async {
    await _czekaj();
    if (kod != '123456') throw BladApi(401, 'Nieprawidłowy kod.');
    return sesja.zPoziomem(sesja.poziom > _poziomDocelowy ? sesja.poziom : _poziomDocelowy);
  }

  int _poziomDocelowy = 2;

  @override
  Future<StanLacza> stan(String token, {String? przylacze}) async {
    await _czekaj();
    return StanLacza(
        ocena: _id == '1002' ? 'uwaga' : (przylacze == 'p2' ? 'zle' : 'ok'),
        wstrzymana: _id == '1002' && !_dwWlaczony,
        onuOnline: przylacze != 'p2',
        sesjaPppoe: przylacze != 'p2',
        restartOnuMozliwy: przylacze == 'p2',
        wylaczeniePradu: przylacze == 'p2' ? 'dziś 9:00–14:00' : null);
  }

  @override
  Future<List<Zgloszenie>> mojeZgloszenia(String token) async {
    await _czekaj();
    return List.of(_zgl.reversed);
  }

  @override
  Future<String> wyslijZgloszenie(String token, Map<String, dynamic> dane) async {
    await _czekaj();
    final nr = 'A${10232 + _zgl.length}';
    _zgl.add(Zgloszenie(numer: nr, status: 'przyjęte', opis: '${dane['opis']}', data: DateTime.now()));
    return nr;
  }

  @override
  Future<String> restartOnu(String token, {String? przylacze}) async {
    await _czekaj();
    return 'Terminal zostanie uruchomiony ponownie. Poczekaj około 3 minut.';
  }

  // Demo diagnozy: przyłącze p2 (ID 999) nie ma sesji, więc EYE próbuje restartu z OLT.
  final _diag = <String, (int, String?)>{};
  bool _dwWlaczony = false;

  @override
  Future<String> startDiagnozy(String token, {String? przylacze}) async {
    await _czekaj();
    final id = 'd${_diag.length + 1}';
    _diag[id] = (0, przylacze);
    return id;
  }

  @override
  Future<Diagnoza> krokDiagnozy(String token, String id) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final (n, przyl) = _diag[id]!;
    _diag[id] = (n + 1, przyl);
    final zla = przyl == 'p2' || _id == '1003'; // 1003: brak sesji (jak w /pomoc/)
    final kody = ['konto', 'onu', 'sesja', 'lan', 'lan_ping', 'brama', 'polska', 'restart_olt', 'internet'];
    final nazwy = {
      'konto': 'Konto i usługa',
      'onu': 'Terminal światłowodowy (ONU)',
      'sesja': 'Połączenie z internetem',
      'lan': 'Port LAN do routera',
      'lan_ping': 'Twoje urządzenia ↔ terminal (ONU)',
      'brama': 'Terminal ↔ koncentrator UltraTech',
      'polska': 'Polskie serwisy internetowe',
      'restart_olt': 'Restart terminala z centrali',
      'internet': 'Sprawdzenie po restarcie',
    };
    // wynik każdego kroku, gdy już jest wykonany
    (String, String?) wynik(String k) => switch (k) {
          'konto' => ('ok', 'Usługa aktywna.'),
          'onu' => ('ok', 'Terminal jest online, sygnał w normie.'),
          'sesja' => zla ? ('blad', 'Brak połączenia z internetem.') : ('ok', 'Połączenie aktywne.'),
          'lan' => zla
              ? ('pominiety', 'Bez połączenia nie można odczytać portu LAN.')
              : ('ok', 'Router podłączony: 1000 Mb/s, ruch jest.'),
          'lan_ping' => zla ? ('pominiety', null) : ('ok', 'Połączenie w porządku.'),
          'brama' => zla ? ('pominiety', null) : ('ok', 'Połączenie w porządku.'),
          'polska' => zla ? ('pominiety', null) : ('ok', 'Serwisy odpowiadają.'),
          'restart_olt' => zla ? ('ok', 'Terminal uruchomiony ponownie.') : ('pominiety', 'Niepotrzebny.'),
          _ => zla ? ('ok', 'Połączenie wróciło po restarcie.') : ('pominiety', null),
        };
    final kroki = <KrokDiagnozy>[];
    for (var i = 0; i < kody.length; i++) {
      final k = kody[i];
      final (st, op) = i < n ? wynik(k) : (i == n ? ('trwa', null) : ('czeka', null));
      kroki.add(KrokDiagnozy(kod: k, nazwa: nazwy[k]!, stan: st, opis: op));
    }
    if (_id == '1002') {
      // blokada za płatności: dalsze kroki nie mają sensu
      final k0 = n == 0
          ? KrokDiagnozy(kod: 'konto', nazwa: nazwy['konto']!, stan: 'trwa')
          : KrokDiagnozy(kod: 'konto', nazwa: nazwy['konto']!, stan: 'blad',
              opis: 'Usługa jest wstrzymana. Szczegóły w e-BOK albo w biurze.');
      return Diagnoza(id: id, koniec: n > 0, ocena: n > 0 ? 'blokada' : null, kroki: [
        k0,
        for (final k in kody.skip(1)) KrokDiagnozy(kod: k, nazwa: nazwy[k]!, stan: n > 0 ? 'pominiety' : 'czeka'),
      ], dostepWarunkowy: !_dwWlaczony);
    }
    final koniec = n >= kody.length;
    return Diagnoza(
      id: id,
      koniec: koniec,
      ocena: koniec ? 'ok' : null,
      kroki: kroki,
      lan: n > 3 && !zla ? StanLan(link: true, predkosc: '1000 Mb/s pełny dupleks', ruch: true) : null,
    );
  }

  // Demo testu pod obciążeniem: przez Wi-Fi router/Wi-Fi wypada NIE OK (ONU oddało pełne ~800 Mb/s,
  // urządzenie odebrało mniej), po kablu oba odcinki OK.
  final _obc = <String, (Map<String, dynamic>?, int)>{};

  @override
  Future<String> obciazenieStart(String token, {String? przylacze}) async {
    await _czekaj();
    final id = 'o${_obc.length + 1}';
    _obc[id] = (null, 0);
    return id;
  }

  @override
  Future<void> obciazenieWynik(String token, String id, Map<String, dynamic> dane) async {
    await _czekaj();
    _obc[id] = (dane, 0);
  }

  @override
  Future<void> obciazenieZapis(String token, Map<String, dynamic> dane) async {}

  @override
  Future<WynikObciazenia> obciazenieStan(String token, String id) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final (dane, n) = _obc[id]!;
    _obc[id] = (dane, n + 1);
    if (dane == null || n < 1) return WynikObciazenia(koniec: false, odcinki: []);
    final wifi = (dane['polaczenie'] as Map?)?['rodzaj'] == 'wifi';
    return WynikObciazenia(
      koniec: true,
      odcinki: [
        Odcinek(kod: 'lacze_ut', nazwa: 'Łącze UltraTech do Twojego routera', stan: 'ok',
            opis: 'Terminal przekazał do routera pełną prędkość pakietu.'),
        Odcinek(
            kod: 'router_wifi',
            nazwa: 'Twój router i Wi-Fi do tego urządzenia',
            stan: wifi ? 'blad' : 'ok',
            opis: wifi
                ? 'Część prędkości gubi się między routerem a tym urządzeniem, a opóźnienie mocno rośnie pod obciążeniem.'
                : 'Router i połączenie z tym urządzeniem działają prawidłowo.'),
      ],
      proponujTestKabel: wifi,
    );
  }

  @override
  Future<DostepWarunkowy> dostepWarunkowy(String token) async {
    await _czekaj();
    return _dwWlaczony
        ? DostepWarunkowy(mozliwy: false, aktywny: true, powod: 'Dostęp warunkowy jest już włączony.')
        : DostepWarunkowy(mozliwy: true, dni: 3);
  }

  @override
  Future<String> wlaczDostepWarunkowy(String token) async {
    await _czekaj();
    _dwWlaczony = true;
    final d = DateTime.now().add(const Duration(days: 3));
    return 'Dostęp warunkowy włączony do ${d.day}.${d.month.toString().padLeft(2, '0')}.${d.year}. '
        'Internet zacznie działać w ciągu kilku minut.';
  }

  @override
  Future<List<RouterMesh>> routery(String token) async {
    await _czekaj();
    return [
      RouterMesh(
          id: 'r1', model: 'Uplink AX34H', nazwa: _nazwy['r1']!, glowny: true, online: true,
          firmware: 'UT-OpenWrt 24.10-1', nowyFirmware: 'UT-OpenWrt 24.10-2', klienci: 7),
      RouterMesh(
          id: 'r2', model: 'V-SOL HG3610', nazwa: _nazwy['r2']!, glowny: false, online: true,
          firmware: 'UT-OpenWrt 24.10-2', klienci: 3, jakoscPolaczenia: 'dobra'),
    ];
  }

  @override
  Future<SiecWifi> siecWifi(String token) async {
    await _czekaj();
    return SiecWifi(ssid: _ssid, gosc: _gosc, ssidGosc: '$_ssid-Gosc');
  }

  @override
  Future<void> zapiszSiecWifi(String token, {required String ssid, String? haslo, bool? gosc, String? hasloGosc}) async {
    await _czekaj();
    _ssid = ssid;
    _gosc = gosc ?? _gosc;
  }

  @override
  Future<void> restartRoutera(String token, String id) => _czekaj();
  @override
  Future<void> aktualizujFirmware(String token, String id) => _czekaj();
  @override
  Future<void> zmienNazweRoutera(String token, String id, String nazwa) async {
    await _czekaj();
    _nazwy[id] = nazwa;
  }

  @override
  Future<void> parujWezel(String token) => _czekaj();
}
