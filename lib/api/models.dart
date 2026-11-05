// Modele danych. Pola odpowiadają API klienta EYE (/api/v1/klient/...)
// oraz komunikatom serwisowym EYE. Nazwy po polsku, jak w EYE.

DateTime? _data(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

/// Komunikat na ekranie głównym: awaria, prace planowe, informacja, promocja.
class Komunikat {
  final String id;
  final String typ; // awaria | prace_planowe | informacja | promocja
  final String tytul;
  final String tresc;
  final DateTime? od;
  final DateTime? doKiedy;
  final int priorytet;
  final bool przypiety;
  final DateTime? zaktualizowano;
  final String? link;

  Komunikat({
    required this.id,
    required this.typ,
    required this.tytul,
    required this.tresc,
    this.od,
    this.doKiedy,
    this.priorytet = 0,
    this.przypiety = false,
    this.zaktualizowano,
    this.link,
  });

  bool get serwisowy => typ != 'promocja';

  factory Komunikat.fromJson(Map<String, dynamic> j) => Komunikat(
        id: '${j['id']}',
        typ: '${j['typ'] ?? 'informacja'}',
        tytul: '${j['tytul'] ?? ''}',
        tresc: '${j['tresc'] ?? ''}',
        od: _data(j['od']),
        doKiedy: _data(j['do']),
        priorytet: int.tryParse('${j['priorytet'] ?? 0}') ?? 0,
        przypiety: j['przypiety'] == true || j['przypiety'] == 1,
        zaktualizowano: _data(j['zaktualizowano']),
        link: j['link'] as String?,
      );
}

/// Wynik logowania. poziom: 1 = ID+PIN (test), 2 = potwierdzony SMS (zgłoszenie),
/// 3 = SMS na numer z net47 (ujemne saldo, restart ONU).
class Sesja {
  final String token;
  final int poziom;
  final DateTime? wygasa;
  final List<Przylacze> przylacza;

  Sesja({required this.token, required this.poziom, this.wygasa, this.przylacza = const []});

  Sesja zPoziomem(int p, {String? nowyToken}) =>
      Sesja(token: nowyToken ?? token, poziom: p, wygasa: wygasa, przylacza: przylacza);

  factory Sesja.fromJson(Map<String, dynamic> j) => Sesja(
        token: '${j['token']}',
        poziom: int.tryParse('${j['poziom'] ?? 1}') ?? 1,
        wygasa: _data(j['wygasa']),
        przylacza: ((j['przylacza'] as List?) ?? [])
            .map((e) => Przylacze.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Przyłącze klienta (gdy jedno ID ma kilka adresów). Adres skrócony, bez nazwiska.
class Przylacze {
  final String id;
  final String adres;
  Przylacze({required this.id, required this.adres});
  factory Przylacze.fromJson(Map<String, dynamic> j) =>
      Przylacze(id: '${j['id']}', adres: '${j['adres'] ?? ''}');
}

/// Stan łącza z EYE. Klientowi pokazujemy tylko ocenę słowną, bez dBm i IP.
class StanLacza {
  final String ocena; // ok | uwaga | zle
  final String? opis;
  final bool onuOnline;
  final bool sesjaPppoe;
  final bool wstrzymana; // blokada za płatności (bez kwot)
  final String? awariaMasowa; // opis awarii w okolicy, jeśli jest
  final String? wylaczeniePradu; // "od–do" w okolicy, jeśli jest
  final String? otwarteZgloszenie; // numer otwartego zgłoszenia
  final bool restartOnuMozliwy;

  StanLacza({
    required this.ocena,
    this.opis,
    required this.onuOnline,
    required this.sesjaPppoe,
    this.wstrzymana = false,
    this.awariaMasowa,
    this.wylaczeniePradu,
    this.otwarteZgloszenie,
    this.restartOnuMozliwy = false,
  });

  /// Łączy odpowiedzi EYE: GET /klient/stan, GET /klient/poziom, GET /klient/wylaczenia-pradu.
  factory StanLacza.fromJson(Map<String, dynamic> j, {Map<String, dynamic>? poziom, Map<String, dynamic>? wylaczenia}) {
    final onu = j['onu_online'] != false;
    final internet = (j['internet'] ?? j['sesja_pppoe']) != false;
    String? prad;
    final w = (wylaczenia?['wylaczenia'] as List?) ?? const [];
    if (w.isNotEmpty && w.first is Map) {
      final m = w.first as Map;
      prad = [m['od'], m['do']].where((e) => e != null && '$e'.isNotEmpty).join(' – ');
    }
    return StanLacza(
      ocena: '${j['stan'] ?? j['ocena'] ?? 'uwaga'}',
      opis: j['opis'] as String?,
      onuOnline: onu,
      sesjaPppoe: internet,
      wstrzymana: poziom?['ujemne_saldo'] == true || j['wstrzymana'] == true,
      awariaMasowa: j['awaria_masowa'] as String?,
      wylaczeniePradu: prad ?? j['wylaczenie_pradu'] as String?,
      otwarteZgloszenie: j['otwarte_zgloszenie']?.toString(),
      restartOnuMozliwy: j['restart_mozliwy'] == true || j['restart_onu_mozliwy'] == true,
    );
  }
}

class Zgloszenie {
  final String numer;
  final String status;
  final String opis;
  final DateTime? data;
  Zgloszenie({required this.numer, required this.status, required this.opis, this.data});
  /// Kształt z EYE: {id, zgloszono, otwarta, opis, rozwiazanie, zamknieto}.
  factory Zgloszenie.fromJson(Map<String, dynamic> j) => Zgloszenie(
        numer: j['numer']?.toString() ?? 'A${j['id']}',
        status: j['status']?.toString() ??
            (j['otwarta'] == true || j['otwarta'] == 1 ? 'w realizacji' : 'zamknięte'),
        opis: '${j['opis'] ?? ''}${j['rozwiazanie'] != null ? '\nRozwiązanie: ${j['rozwiazanie']}' : ''}',
        data: _data(j['data'] ?? j['zgloszono']),
      );
}

/// Opóźnienie urządzenie → serwer testu w spoczynku i pod obciążeniem (bufferbloat).
class Opoznienie {
  final double spoczynekMs;
  final double pobMedMs, pobP90Ms, wysMedMs, wysP90Ms;
  final double jitterMs;
  final double bezOdpProc; // próbki bez odpowiedzi w 2 s
  const Opoznienie({
    required this.spoczynekMs,
    required this.pobMedMs,
    required this.pobP90Ms,
    required this.wysMedMs,
    required this.wysP90Ms,
    required this.jitterMs,
    required this.bezOdpProc,
  });
  Map<String, dynamic> toJson() => {
        'spoczynek_ms': spoczynekMs.round(),
        'pob_med_ms': pobMedMs.round(),
        'pob_p90_ms': pobP90Ms.round(),
        'wys_med_ms': wysMedMs.round(),
        'wys_p90_ms': wysP90Ms.round(),
        'jitter_ms': jitterMs.round(),
        'bez_odp_proc': double.parse(bezOdpProc.toStringAsFixed(1)),
      };
}

/// Typ połączenia urządzenia i (gdzie system pozwala) parametry Wi-Fi. Tylko do raportu.
class Polaczenie {
  final String rodzaj; // wifi | kabel_router | kabel_onu | komorkowe | nieznany
  final String zrodlo; // system | klient
  final int? sygnalDbm;
  final int? rateMbps;
  final String? pasmo; // 2,4 GHz | 5 GHz | 6 GHz
  const Polaczenie({required this.rodzaj, required this.zrodlo, this.sygnalDbm, this.rateMbps, this.pasmo});
  Map<String, dynamic> toJson() =>
      {'rodzaj': rodzaj, 'zrodlo': zrodlo, 'sygnal_dbm': ?sygnalDbm, 'rate_mbps': ?rateMbps, 'pasmo': ?pasmo};
  String get opis => [
        rodzaj,
        ?pasmo,
        if (sygnalDbm != null) '$sygnalDbm dBm',
        if (rateMbps != null) 'rate $rateMbps Mb/s',
      ].join(', ');
}

/// Wynik testu prędkości. Prędkości to wartości ustalone (bez boostu z pierwszych sekund).
class WynikTestu {
  final double pobieranieMbps;
  final double wysylanieMbps;
  final double pingMs; // spoczynek
  final double jitterMs;
  final String polaczenie; // wifi | kabel_router | kabel_onu | komorkowe
  final DateTime kiedy;
  final Opoznienie? opoznienie;
  final Polaczenie? siec;
  final String? idObciazenia; // pomiar EYE w tym samym oknie
  final String metoda; // http | iperf3
  final int? retransmisje; // TCP po stronie serwera iperf3 przy pobieraniu
  WynikTestu({
    required this.pobieranieMbps,
    required this.wysylanieMbps,
    required this.pingMs,
    required this.jitterMs,
    required this.polaczenie,
    required this.kiedy,
    this.opoznienie,
    this.siec,
    this.idObciazenia,
    this.metoda = 'http',
    this.retransmisje,
  });

  /// Linia do pola raport_test zgłoszenia w EYE (klient tych liczb nie widzi na ekranie).
  String doRaportu() {
    final o = opoznienie;
    return 'Test z aplikacji (${kiedy.toLocal().toString().substring(0, 16)}, ${siec?.opis ?? polaczenie}): '
        'pob. ${pobieranieMbps.toStringAsFixed(1)} Mb/s, wys. ${wysylanieMbps.toStringAsFixed(1)} Mb/s (ustalone, bez boostu, $metoda'
        '${retransmisje == null ? '' : ', retransmisje $retransmisje'}); '
        'opóźnienie ${pingMs.toStringAsFixed(0)} ms'
        '${o == null ? '' : ' -> ${o.pobMedMs.toStringAsFixed(0)}/${o.pobP90Ms.toStringAsFixed(0)} ms pob., '
            '${o.wysMedMs.toStringAsFixed(0)}/${o.wysP90Ms.toStringAsFixed(0)} ms wys. (mediana/p90), '
            'brak odp. ${o.bezOdpProc.toStringAsFixed(1)}%'}, jitter ${jitterMs.toStringAsFixed(0)} ms';
  }
}

/// Werdykt EYE dla odcinka po teście pod obciążeniem. stan: ok | blad | brak_danych.
class Odcinek {
  final String kod; // lacze_ut | router_wifi
  final String nazwa;
  final String stan;
  final String? opis;
  Odcinek({required this.kod, required this.nazwa, required this.stan, this.opis});
  factory Odcinek.fromJson(Map<String, dynamic> j) =>
      Odcinek(kod: '${j['kod']}', nazwa: '${j['nazwa'] ?? j['kod']}', stan: '${j['stan'] ?? 'brak_danych'}', opis: j['opis'] as String?);
}

class WynikObciazenia {
  final bool koniec;
  final List<Odcinek> odcinki;
  final bool proponujTestKabel;
  WynikObciazenia({required this.koniec, required this.odcinki, this.proponujTestKabel = false});
  factory WynikObciazenia.fromJson(Map<String, dynamic> j) => WynikObciazenia(
        koniec: j['koniec'] == true,
        odcinki: ((j['odcinki'] as List?) ?? []).map((e) => Odcinek.fromJson((e as Map).cast<String, dynamic>())).toList(),
        proponujTestKabel: j['proponuj_test_kabel'] == true,
      );
}

/// Router WiFi mesh od UT (np. Uplink AX34H, V-SOL). Firmware: projekt WiFi_openwrt.
class RouterMesh {
  final String id;
  final String model;
  final String nazwa; // "Salon", "Piętro"
  final bool glowny;
  final bool online;
  final String firmware;
  final String? nowyFirmware;
  final int klienci;
  final String? jakoscPolaczenia; // dla węzłów: dobra | slaba
  RouterMesh({
    required this.id,
    required this.model,
    required this.nazwa,
    required this.glowny,
    required this.online,
    required this.firmware,
    this.nowyFirmware,
    this.klienci = 0,
    this.jakoscPolaczenia,
  });
  factory RouterMesh.fromJson(Map<String, dynamic> j) => RouterMesh(
        id: '${j['id']}',
        model: '${j['model'] ?? ''}',
        nazwa: '${j['nazwa'] ?? ''}',
        glowny: j['glowny'] == true,
        online: j['online'] == true,
        firmware: '${j['firmware'] ?? ''}',
        nowyFirmware: j['nowy_firmware'] as String?,
        klienci: int.tryParse('${j['klienci'] ?? 0}') ?? 0,
        jakoscPolaczenia: j['jakosc_polaczenia'] as String?,
      );
}

class SiecWifi {
  final String ssid;
  final bool siec5gOsobno;
  final bool gosc;
  final String? ssidGosc;
  SiecWifi({required this.ssid, this.siec5gOsobno = false, this.gosc = false, this.ssidGosc});
  factory SiecWifi.fromJson(Map<String, dynamic> j) => SiecWifi(
        ssid: '${j['ssid'] ?? ''}',
        siec5gOsobno: j['siec_5g_osobno'] == true,
        gosc: j['gosc'] == true,
        ssidGosc: j['ssid_gosc'] as String?,
      );
}

/// Błąd API z czytelnym komunikatem po polsku.
class BladApi implements Exception {
  final int kod;
  final String komunikat;
  final int? wymaganyPoziom;
  BladApi(this.kod, this.komunikat, {this.wymaganyPoziom});
  @override
  String toString() => komunikat;
}

/// Krok diagnozy EYE. stan: czeka | trwa | ok | uwaga | blad | pominiety.
/// kod: konto | onu | sesja | lan | lan_ping | brama | polska | restart_olt | internet.
/// Kroki z pingami (lan_ping, brama, polska) mają w opisie tylko werdykt, bez liczb.
class KrokDiagnozy {
  final String kod;
  final String nazwa;
  final String stan;
  final String? opis;
  KrokDiagnozy({required this.kod, required this.nazwa, required this.stan, this.opis});
  factory KrokDiagnozy.fromJson(Map<String, dynamic> j) => KrokDiagnozy(
        kod: '${j['kod'] ?? ''}',
        nazwa: '${j['nazwa'] ?? j['kod'] ?? ''}',
        stan: '${j['stan'] ?? 'czeka'}',
        opis: j['opis'] as String?,
      );
}

/// Port LAN terminala (ONU): czy jest podłączone urządzenie, z jaką prędkością i czy płynie ruch.
class StanLan {
  final bool link;
  final String? predkosc;
  final bool ruch;
  StanLan({required this.link, this.predkosc, required this.ruch});
  factory StanLan.fromJson(Map<String, dynamic> j) =>
      StanLan(link: j['link'] == true, predkosc: j['predkosc'] as String?, ruch: j['ruch'] == true);
}

/// Odpowiedź GET /klient/diagnoza/{id}. Każde wywołanie wykonuje w EYE jeden kolejny krok.
/// ocena: ok | router | swiatlowod | zasilanie | awaria_masowa | onu_offline | blokada | brak_danych.
class Diagnoza {
  final String id;
  final bool koniec;
  final String? ocena;
  final List<KrokDiagnozy> kroki;
  final StanLan? lan;
  final bool dostepWarunkowy; // klient może włączyć dostęp warunkowy
  Diagnoza({required this.id, required this.koniec, this.ocena, required this.kroki, this.lan, this.dostepWarunkowy = false});

  double get postep {
    if (koniec || kroki.isEmpty) return koniec ? 1 : 0;
    final zrobione = kroki.where((k) => !const ['czeka', 'trwa'].contains(k.stan)).length;
    return zrobione / kroki.length;
  }

  factory Diagnoza.fromJson(String id, Map<String, dynamic> j) => Diagnoza(
        id: id,
        koniec: j['koniec'] == true,
        ocena: j['ocena'] as String?,
        kroki: ((j['kroki'] as List?) ?? []).map((e) => KrokDiagnozy.fromJson(e as Map<String, dynamic>)).toList(),
        lan: j['lan'] is Map ? StanLan.fromJson((j['lan'] as Map).cast<String, dynamic>()) : null,
        dostepWarunkowy: j['dostep_warunkowy'] == true,
      );
}

/// GET /klient/dostep-warunkowy. Tylko przy blokadzie za płatności, raz na ok. 2 miesiące.
class DostepWarunkowy {
  final bool mozliwy;
  final bool aktywny;
  final String? powod;
  final String? nastepnyOd;
  final int dni;
  DostepWarunkowy({required this.mozliwy, this.aktywny = false, this.powod, this.nastepnyOd, this.dni = 3});
  factory DostepWarunkowy.fromJson(Map<String, dynamic> j) => DostepWarunkowy(
        mozliwy: j['mozliwy'] == true,
        aktywny: j['aktywny'] == true,
        powod: j['powod'] as String?,
        nastepnyOd: j['nastepny_od'] as String?,
        dni: int.tryParse('${j['dni'] ?? 3}') ?? 3,
      );
}
