import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/models.dart';

import '../main.dart';
import '../config.dart';
import '../services/ranking_serwisow.dart';
import '../services/rodzaj_sieci.dart';
import '../services/test_predkosci.dart';
import '../platforma.dart';
import '../widgets/wspolne.dart';
import 'diagnoza_karta.dart';

/// Test łącza: (1) stan przyłącza z EYE, (2) test prędkości z telefonu do sieci UT.
class TestEkran extends StatelessWidget {
  const TestEkran({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Naglowek('Stan przyłącza (z systemu UltraTech)'),
      const KartaStanu(),
      Naglowek(naKomputerze ? 'Test prędkości z tego komputera' : 'Test prędkości z telefonu'),
      const KartaTestu(),
    ],
  );
}

class KartaTestu extends StatefulWidget {
  const KartaTestu({super.key});
  @override
  State<KartaTestu> createState() => _KartaTestuState();
}

/// Test prędkości pod obciążeniem. Klient widzi prędkość (ustaloną, bez boostu) i werdykty:
/// opóźnienie, polskie serwisy oraz, po zalogowaniu, dwa odcinki z EYE:
/// „Łącze UltraTech do Twojego routera” i „Twój router i Wi-Fi”. Liczby idą do zgłoszenia.
class _KartaTestuState extends State<KartaTestu> {
  TestPredkosci? _test;
  PostepTestu? _postep;
  double? _ping, _pob, _wys;
  String _polaczenie = naKomputerze ? 'kabel_router' : 'wifi';
  bool _wykryto = false;
  String? _blad;
  bool? _serwisyOk;
  bool _sprawdzamSerwisy = false;
  WynikTestu? _wynik;
  WynikObciazenia? _odcinki;
  bool _czekamNaEye = false;

  static const _opcje = {
    'wifi': ('Wi-Fi', Icons.wifi),
    'kabel_router': ('Kabel do routera', Icons.settings_ethernet),
    'kabel_onu': ('Kabel do terminala', Icons.cable),
    'komorkowe': ('Sieć komórkowa', Icons.signal_cellular_alt),
  };

  @override
  void initState() {
    super.initState();
    RodzajSieci.wykryj().then((p) {
      if (!mounted) return;
      setState(() {
        if (p.rodzaj != 'nieznany' && p.zrodlo == 'system') {
          _polaczenie = p.rodzaj;
          _wykryto = true;
        }
      });
    });
  }

  Future<void> _start() async {
    final stan = StanScope.of(context);
    final siec = await RodzajSieci.wykryj();
    if (!mounted) return;
    // Klient może poprawić rodzaj (np. kabel do terminala zamiast do routera); system wie tylko „kabel”.
    final polaczenie = Polaczenie(
      rodzaj: _polaczenie,
      zrodlo: siec.rodzaj == _polaczenie || (siec.rodzaj == 'kabel_router' && _polaczenie == 'kabel_onu') ? 'system' : 'klient',
      sygnalDbm: siec.sygnalDbm,
      rateMbps: siec.rateMbps,
      pasmo: siec.pasmo,
    );
    setState(() {
      _test = TestPredkosci();
      _ping = _pob = _wys = null;
      _serwisyOk = null;
      _blad = null;
      _wynik = null;
      _odcinki = null;
    });
    final test = _test!;
    try {
      await for (final p in test.uruchom(
        polaczenie: _polaczenie,
        siec: polaczenie,
        startObciazenia: stan.zalogowany && _polaczenie != 'komorkowe'
            ? () => stan.api.obciazenieStart(stan.token, przylacze: stan.przylacze?.id)
            : null,
        gotowe: (w) {
          stan.zapiszTest(w);
          _wynik = w;
        },
      )) {
        if (!mounted) return;
        setState(() {
          _postep = p;
          switch (p.faza) {
            case Faza.ping:
              _ping = p.wartosc;
            case Faza.pobieranie:
              _pob = p.wartosc;
            case Faza.wysylanie:
              _wys = p.wartosc;
            case Faza.koniec:
              break;
          }
        });
      }
      if (mounted && _wynik?.idObciazenia != null) {
        await _werdyktEye(test, _wynik!, polaczenie);
      } else if (mounted && _wynik != null && StanScope.of(context).zalogowany) {
        await _zapiszBezWerdyktu(test, _wynik!, polaczenie);
      }
      // Dostępność polskich serwisów: klient widzi tylko werdykt, czasy idą do zgłoszenia.
      if (mounted && _test != null) {
        setState(() => _sprawdzamSerwisy = true);
        final r = await RankingSerwisow.zmierz(demo: Config.demo);
        stan.zapiszRanking(r);
        if (mounted) setState(() => _serwisyOk = r == null ? null : RankingSerwisow.ok(r));
      }
    } catch (e) {
      if (mounted) setState(() => _blad = 'Nie udało się połączyć z serwerem testowym UltraTech.');
    } finally {
      if (mounted) {
        setState(() {
          _test = null;
          _sprawdzamSerwisy = false;
          _czekamNaEye = false;
        });
      }
    }
  }

  Map<String, dynamic> _daneWyniku(TestPredkosci test, WynikTestu w, Polaczenie polaczenie) => {
    'okna': test.okna.toJson(),
    'pobieranie_mbps': double.parse(w.pobieranieMbps.toStringAsFixed(1)),
    'wysylanie_mbps': double.parse(w.wysylanieMbps.toStringAsFixed(1)),
    'opoznienie': w.opoznienie?.toJson(),
    'polaczenie': polaczenie.toJson(),
    'urzadzenie': kIsWeb ? 'przegladarka' : (naKomputerze ? 'komputer' : 'telefon'),
    'metoda': w.metoda, // http | iperf3 (CCR2216)
    'retransmisje': ?w.retransmisje,
  };

  /// EYE nie przyjął startu pomiaru (np. limit 429): wynik i tak trafia do karty klienta, bez werdyktu.
  Future<void> _zapiszBezWerdyktu(TestPredkosci test, WynikTestu w, Polaczenie polaczenie) async {
    final stan = StanScope.of(context);
    try {
      await stan.api.obciazenieZapis(stan.token, _daneWyniku(test, w, polaczenie));
    } catch (_) {}
  }

  /// Wysyła do EYE wyniki z okien bez boostu i czeka na werdykty odcinków.
  Future<void> _werdyktEye(TestPredkosci test, WynikTestu w, Polaczenie polaczenie) async {
    final stan = StanScope.of(context);
    setState(() => _czekamNaEye = true);
    try {
      await stan.api.obciazenieWynik(stan.token, w.idObciazenia!, _daneWyniku(test, w, polaczenie));
      for (var i = 0; i < 20 && mounted; i++) {
        final o = await stan.api.obciazenieStan(stan.token, w.idObciazenia!);
        if (o.koniec) {
          if (mounted) setState(() => _odcinki = o);
          break;
        }
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } catch (_) {
      // bez werdyktu EYE zostaje sam test prędkości
    } finally {
      if (mounted) setState(() => _czekamNaEye = false);
    }
  }

  @override
  void dispose() {
    _test?.przerwij();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trwa = _test != null;
    final stan = StanScope.of(context);
    final opcje = _opcje.entries.where((e) => naKomputerze ? e.key != 'komorkowe' : true).toList();
    final o = _wynik?.opoznienie;
    return Karta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            naKomputerze
                ? 'Mierzy prędkość między tym komputerem a serwerem w sieci UltraTech oraz to, czy połączenie wytrzymuje pełne obciążenie.'
                : 'Mierzy prędkość między telefonem a serwerem w sieci UltraTech oraz to, czy połączenie wytrzymuje pełne obciążenie. '
                      'Aby sprawdzić łącze domowe, połącz telefon z domowym Wi-Fi.',
          ),
          const SizedBox(height: 12),
          Text(
            _wykryto ? 'Połączenie (rozpoznane automatycznie, możesz zmienić):' : 'Jak to urządzenie jest połączone?',
            style: const TextStyle(color: Kolory.tekst2, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in opcje)
                ChoiceChip(
                  avatar: Icon(e.value.$2, size: 18),
                  label: Text(e.value.$1),
                  selected: _polaczenie == e.key,
                  onSelected: trwa ? null : (_) => setState(() => _polaczenie = e.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Wynik('Pobieranie', _pob, 'Mb/s', aktywny: _postep?.faza == Faza.pobieranie && trwa),
              _Wynik('Wysyłanie', _wys, 'Mb/s', aktywny: _postep?.faza == Faza.wysylanie && trwa),
            ],
          ),
          if (trwa && (_postep?.faza == Faza.pobieranie || _postep?.faza == Faza.wysylanie) && (_pob ?? 0) == 0 && (_wys ?? 0) == 0)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Pierwsze sekundy pomijamy: łącze na starcie bywa szybsze niż w pakiecie.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Kolory.tekst2, fontSize: 12),
              ),
            ),
          // Werdykty bez liczb (decyzja z 05.11.2026); liczby idą do zgłoszenia.
          if (o != null)
            _Werdykt(
              'Opóźnienie pod obciążeniem',
              o.pobMedMs - o.spoczynekMs <= 100 && o.wysMedMs - o.spoczynekMs <= 100 && o.bezOdpProc <= 2,
              ok: 'w normie',
              zle: 'mocno rośnie',
            )
          else if (_ping != null && !(trwa && _postep?.faza == Faza.ping))
            _Werdykt('Opóźnienie do sieci UltraTech', _ping! < 40, ok: 'w normie', zle: 'podwyższone'),
          if (_czekamNaEye) const _Werdykt('Sprawdzam odcinki po stronie UltraTech', null),
          if (_odcinki != null)
            for (final od in _odcinki!.odcinki)
              _Werdykt(
                od.nazwa,
                od.stan == 'brak_danych' ? null : od.stan == 'ok',
                ok: 'OK',
                zle: 'NIE OK',
                opis: od.opis,
                brakDanych: od.stan == 'brak_danych',
              ),
          if (_sprawdzamSerwisy) const _Werdykt('Polskie serwisy internetowe', null),
          if (_serwisyOk != null) _Werdykt('Polskie serwisy internetowe', _serwisyOk, ok: 'dostępne', zle: 'większość nie odpowiada'),
          if (!trwa && _odcinki?.proponujTestKabel == true) _PropozycjaKabla(polaczenie: _polaczenie),
          if (!trwa && _wynik != null && !stan.zalogowany)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Zaloguj się, a sprawdzimy też, czy problem jest po naszej stronie, czy w Twoim routerze lub Wi-Fi.',
                style: TextStyle(color: Kolory.tekst2, fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          if (trwa) LinearProgressIndicator(value: _postep?.postep, minHeight: 6, borderRadius: BorderRadius.circular(3)),
          if (_blad != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_blad!, style: const TextStyle(color: Color(0xFFB42318))),
            ),
          if (_polaczenie == 'komorkowe')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Uwaga: przez sieć komórkową mierzysz łącze operatora komórkowego, nie internet UltraTech.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: trwa ? () => _test?.przerwij() : _start,
            icon: Icon(trwa ? Icons.stop : Icons.play_arrow),
            label: Text(trwa ? 'Przerwij' : (_pob == null ? 'Rozpocznij test' : 'Powtórz test')),
          ),
          if (!trwa && stan.proby.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Wyniki ${stan.proby.length == 1 ? 'testu' : '${stan.proby.length} prób'} dołączymy do zgłoszenia awarii, jeśli je wyślesz.',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

/// Przy NIE OK na odcinku router/Wi-Fi: test porównawczy po kablu, który klient robi sam.
class _PropozycjaKabla extends StatelessWidget {
  final String polaczenie;
  const _PropozycjaKabla({required this.polaczenie});
  @override
  Widget build(BuildContext context) {
    final krok = polaczenie == 'kabel_router'
        ? 'Podłącz laptop kablem prosto do terminala światłowodowego (z pominięciem routera) i powtórz test, wybierając „Kabel do terminala”.'
        : 'Podłącz laptop kablem do swojego routera i powtórz test w aplikacji UltraTech na komputerze albo w panelu na ultratech.net.pl, wybierając „Kabel do routera”.';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE9D7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sprawdź sam, gdzie gubi się prędkość', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(krok),
          const SizedBox(height: 4),
          const Text(
            'Jeśli po kablu wynik będzie dobry, problem jest w Wi-Fi albo w routerze. Wszystkie próby trafią do zgłoszenia.',
            style: TextStyle(color: Kolory.tekst2, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Wynik extends StatelessWidget {
  final String etykieta;
  final double? wartosc;
  final String jednostka;
  final bool aktywny;
  const _Wynik(this.etykieta, this.wartosc, this.jednostka, {this.aktywny = false});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          etykieta,
          style: TextStyle(color: aktywny ? Kolory.pomarancz : Kolory.tekst2, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          wartosc == null ? '–' : wartosc!.toStringAsFixed(1),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: Kolory.granat),
        ),
        Text(jednostka, style: const TextStyle(color: Kolory.tekst2, fontSize: 12)),
      ],
    ),
  );
}

class _Werdykt extends StatelessWidget {
  final String co;
  final bool? wynik; // null = sprawdzanie (albo brak danych)
  final String ok;
  final String zle;
  final String? opis;
  final bool brakDanych;
  const _Werdykt(this.co, this.wynik, {this.ok = 'OK', this.zle = 'problem', this.opis, this.brakDanych = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (brakDanych)
          const Icon(Icons.help_outline, color: Colors.black38, size: 20)
        else if (wynik == null)
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
        else
          Icon(wynik! ? Icons.check_circle : Icons.error, color: wynik! ? Kolory.zielony : const Color(0xFFB42318), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$co: '),
                    TextSpan(
                      text: brakDanych ? 'brak danych' : (wynik == null ? 'sprawdzam…' : (wynik! ? ok : zle)),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (opis != null) Text(opis!, style: const TextStyle(color: Kolory.tekst2, fontSize: 13)),
            ],
          ),
        ),
      ],
    ),
  );
}
