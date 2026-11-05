import 'dart:async';

import 'package:flutter/material.dart';

import '../api/models.dart';
import '../main.dart';
import '../widgets/wspolne.dart';
import 'logowanie_ekran.dart';
import 'sms_ekran.dart';

/// Diagnoza przyłącza z EYE krok po kroku, z widocznym postępem:
/// konto → ONU → sesja → port LAN (negocjacja, ruch) → restart z OLT (gdy brak sesji) → sprawdzenie.
/// Restart z OLT wykonuje sam EYE, tylko gdy nie ma sesji i w dobowym limicie.
class KartaStanu extends StatefulWidget {
  const KartaStanu({super.key});
  @override
  State<KartaStanu> createState() => _KartaStanuState();
}

class _KartaStanuState extends State<KartaStanu> {
  Diagnoza? _d;
  bool _trwa = false;
  bool _przerwano = false;

  Future<void> _uruchom() async {
    final s = StanScope.of(context);
    setState(() {
      _trwa = true;
      _przerwano = false;
      _d = null;
    });
    try {
      final id = await s.api.startDiagnozy(s.token, przylacze: s.przylacze?.id);
      while (mounted && !_przerwano) {
        final d = await s.api.krokDiagnozy(s.token, id);
        if (!mounted) return;
        setState(() => _d = d);
        if (d.koniec) break;
        await Future.delayed(const Duration(seconds: 1));
      }
    } catch (e) {
      if (mounted) obsluzBlad(context, e);
    } finally {
      if (mounted) setState(() => _trwa = false);
    }
  }

  @override
  void dispose() {
    _przerwano = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = StanScope.of(context);
    if (!s.zalogowany) {
      return Karta(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sprawdzimy po stronie sieci UltraTech terminal światłowodowy, połączenie z internetem '
              'i port, do którego podłączony jest Twój router. Do tego potrzebne jest ID klienta i PIN e-BOK.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.login),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LogowanieEkran())),
            label: const Text('Zaloguj się'),
          ),
        ]),
      );
    }
    final d = _d;
    return Karta(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const WyborPrzylacza(),
        if (d != null) ...[
          if (!d.koniec)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sprawdzanie… ${(d.postep * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: d.postep, minHeight: 6, borderRadius: BorderRadius.circular(3)),
              ]),
            )
          else
            Padding(padding: const EdgeInsets.only(bottom: 8), child: _Ocena(d.ocena)),
          for (final k in d.kroki) _Krok(k),
          if (d.lan != null) _Lan(d.lan!),
          if (d.koniec && d.dostepWarunkowy) const Padding(padding: EdgeInsets.only(top: 12), child: KartaDostepuWarunkowego()),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: _trwa ? () => setState(() => _przerwano = true) : _uruchom,
          icon: _trwa
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.network_check),
          label: Text(_trwa ? 'Przerwij' : (d == null ? 'Sprawdź przyłącze' : 'Sprawdź ponownie')),
        ),
        if (!_trwa && d == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Jeśli terminal nie ma połączenia, system spróbuje go zdalnie uruchomić ponownie. Trwa to do 3 minut.',
                style: TextStyle(color: Colors.black54, fontSize: 13)),
          ),
      ]),
    );
  }
}

class _Krok extends StatelessWidget {
  final KrokDiagnozy k;
  const _Krok(this.k);
  @override
  Widget build(BuildContext context) {
    final Widget ikona = switch (k.stan) {
      'trwa' => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
      'ok' => const Icon(Icons.check_circle, color: Kolory.zielony, size: 22),
      'uwaga' => const Icon(Icons.error, color: Color(0xFFB54708), size: 22),
      'blad' => const Icon(Icons.cancel, color: Color(0xFFB42318), size: 22),
      'pominiety' => const Icon(Icons.remove_circle_outline, color: Colors.black26, size: 22),
      _ => const Icon(Icons.radio_button_unchecked, color: Colors.black26, size: 22),
    };
    final wyszarz = k.stan == 'czeka' || k.stan == 'pominiety';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 24, child: Center(child: ikona)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k.nazwa,
                style: TextStyle(fontWeight: FontWeight.w600, color: wyszarz ? Colors.black45 : Kolory.granat)),
            if (k.opis != null && k.opis!.isNotEmpty)
              Text(k.opis!, style: TextStyle(color: wyszarz ? Colors.black38 : Kolory.tekst2, fontSize: 13)),
            if (k.stan == 'trwa' && k.kod == 'restart_olt')
              const Text('Terminal uruchamia się ponownie, to potrwa około 2 minut. Nie wyłączaj go z prądu.',
                  style: TextStyle(color: Kolory.tekst2, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

class _Lan extends StatelessWidget {
  final StanLan lan;
  const _Lan(this.lan);
  @override
  Widget build(BuildContext context) {
    final tekst = !lan.link
        ? 'Do terminala nie jest podłączony żaden router ani komputer. Sprawdź kabel w porcie LAN.'
        : '${lan.predkosc ?? 'Połączenie jest'}. ${lan.ruch ? 'Dane płyną między terminalem a routerem.' : 'Brak ruchu: router może być zawieszony, spróbuj go zrestartować.'}';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF1F4F8), borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.settings_ethernet, color: lan.link && lan.ruch ? Kolory.zielony : const Color(0xFFB54708)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Port LAN terminala', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(tekst),
          ]),
        ),
      ]),
    );
  }
}

class _Ocena extends StatelessWidget {
  final String? ocena;
  const _Ocena(this.ocena);
  static const _czerwony = Color(0xFFB42318);
  static const _pomarancz = Color(0xFFB54708);
  @override
  Widget build(BuildContext context) {
    final (kolor, tytul, rada) = switch (ocena) {
      'ok' => (Kolory.zielony, 'Łącze działa prawidłowo', 'Jeśli internet nadal nie działa, problem jest najpewniej w routerze lub WiFi. Zrób test prędkości poniżej.'),
      'router' => (_pomarancz, 'Problem z routerem', 'Światłowód działa. Uruchom ponownie router (wyłącz z prądu na 30 sekund) i sprawdź kabel do terminala.'),
      'swiatlowod' => (_czerwony, 'Problem ze światłowodem', 'Sprawdź, czy na terminalu nie świeci czerwona dioda LOS. Zgłoś awarię, serwis sprawdzi linię.'),
      'zasilanie' => (_czerwony, 'Terminal bez zasilania', 'Sprawdź, czy terminal jest podłączony do prądu i włączony.'),
      'awaria_masowa' => (_czerwony, 'Awaria w Twojej okolicy', 'Serwis już nad nią pracuje. Nie musisz jej zgłaszać.'),
      'onu_offline' => (_czerwony, 'Terminal nie odpowiada', 'Sprawdź zasilanie terminala i diodę PON. Jeśli to nie pomoże, zgłoś awarię.'),
      'blokada' => (_pomarancz, 'Usługa jest wstrzymana', 'Szczegóły w e-BOK albo w biurze.'),
      _ => (_pomarancz, 'Nie udało się sprawdzić wszystkiego', 'Spróbuj ponownie za chwilę albo zgłoś awarię.'),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kolor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.circle, color: kolor, size: 14),
          const SizedBox(width: 10),
          Expanded(child: Text(tytul, style: TextStyle(color: kolor, fontWeight: FontWeight.w700, fontSize: 16))),
        ]),
        const SizedBox(height: 4),
        Text(rada),
      ]),
    );
  }
}

/// Dostęp warunkowy: przy blokadzie za płatności klient może sam włączyć internet na kilka dni,
/// najwyżej raz na ok. 2 miesiące (reguły EYE). Wymaga numeru z umowy (poziom 3).
class KartaDostepuWarunkowego extends StatefulWidget {
  const KartaDostepuWarunkowego({super.key});
  @override
  State<KartaDostepuWarunkowego> createState() => _KartaDostepuWarunkowegoState();
}

class _KartaDostepuWarunkowegoState extends State<KartaDostepuWarunkowego> {
  Future<DostepWarunkowy>? _stan;
  bool _trwa = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = StanScope.of(context);
    _stan ??= s.api.dostepWarunkowy(s.token);
  }

  Future<void> _wlacz(DostepWarunkowy dw) async {
    if (StanScope.of(context).poziom < 3) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SmsEkran(rozszerzony: true)));
      if (!mounted || StanScope.of(context).poziom < 3) return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Włączyć dostęp warunkowy?'),
        content: Text('Internet zostanie włączony na ${dw.dni} dni mimo zaległości. '
            'Z tej możliwości można skorzystać raz na około 2 miesiące. Zaległość trzeba uregulować w tym czasie.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Włącz')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final s = StanScope.of(context);
    setState(() => _trwa = true);
    try {
      final msg = await s.api.wlaczDostepWarunkowy(s.token);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Kolory.zielony, size: 40),
          content: Text(msg),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
      if (mounted) setState(() => _stan = s.api.dostepWarunkowy(s.token));
    } catch (e) {
      if (mounted) obsluzBlad(context, e);
    } finally {
      if (mounted) setState(() => _trwa = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DostepWarunkowy>(
      future: _stan,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final dw = snap.data!;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF8F1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE9D7))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Dostęp warunkowy', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            if (dw.aktywny)
              const Text('Dostęp warunkowy jest włączony.')
            else if (dw.mozliwy) ...[
              Text('Możesz sam włączyć internet na ${dw.dni} dni, zanim uregulujesz zaległość. '
                  'Raz na około 2 miesiące.'),
              const SizedBox(height: 8),
              FilledButton(
                  onPressed: _trwa ? null : () => _wlacz(dw),
                  child: Text('Włącz internet na ${dw.dni} dni')),
            ] else
              Text(dw.powod ??
                  (dw.nastepnyOd != null
                      ? 'Kolejny dostęp warunkowy będzie możliwy od ${dw.nastepnyOd}. W pilnej sprawie zadzwoń do biura.'
                      : 'Dostęp warunkowy nie jest teraz dostępny. Zadzwoń do biura.')),
          ]),
        );
      },
    );
  }
}
