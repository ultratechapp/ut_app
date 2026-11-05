import 'package:flutter/material.dart';

import '../api/models.dart';
import '../main.dart';
import '../services/ranking_serwisow.dart';
import '../widgets/wspolne.dart';
import 'sms_ekran.dart';

/// Zgłoszenie awarii do EYE.
/// Wymaga logowania (poziom 1). Przed wysłaniem: kod SMS na numer kontaktowy (poziom 2).
/// Jeśli EYE odpowie, że potrzeba poziomu 3 (np. usługa wstrzymana), prosimy o numer z umowy.
class AwariaEkran extends StatelessWidget {
  const AwariaEkran({super.key});
  @override
  Widget build(BuildContext context) => const WymagaPoziomu(
        poziom: 1,
        powod: 'Aby zgłosić awarię, zaloguj się ID klienta i PIN-em e-BOK. '
            'Przed wysłaniem potwierdzisz numer kontaktowy kodem SMS.',
        child: _Formularz(),
      );
}

class _Formularz extends StatefulWidget {
  const _Formularz();
  @override
  State<_Formularz> createState() => _FormularzState();
}

class _FormularzState extends State<_Formularz> {
  static const _rodzaje = {
    'nie_dziala': 'Internet nie działa wcale',
    'dziala_ale': 'Działa, ale wolno lub się rozłącza',
    'wifi': 'Problem z WiFi lub routerem',
    'bok': 'Sprawa do biura (umowa, faktura)',
    'inne': 'Inne',
  };
  static const _objawy = {
    'kabel': 'Komputer po kablu też nie działa',
    'los': 'Na terminalu świeci czerwona dioda LOS',
    'restart': 'Restartowałem już router i terminal',
    'wszyscy': 'Problem mają wszystkie urządzenia w domu',
  };

  String _rodzaj = 'nie_dziala';
  final _zaznaczone = <String>{};
  final _opis = TextEditingController();
  String? _telefon;
  bool _dolaczTest = true;
  bool _trwa = false;
  Future<List<Zgloszenie>>? _moje;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _moje ??= _pobierzMoje();
  }

  Future<List<Zgloszenie>> _pobierzMoje() {
    final s = StanScope.of(context);
    return s.api.mojeZgloszenia(s.token);
  }

  Future<bool> _podnies(int poziom) async {
    final tel = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => SmsEkran(rozszerzony: poziom >= 3)));
    if (tel != null && poziom == 2) _telefon = tel;
    return mounted && StanScope.of(context).poziom >= poziom;
  }

  Future<void> _wyslij() async {
    if (_opis.text.trim().length < 5) {
      pokazKomunikat(context, 'Opisz krótko problem (np. od kiedy nie działa).');
      return;
    }
    var s = StanScope.of(context);
    if (s.poziom < 2 && !await _podnies(2)) return;
    if (!mounted) return;
    s = StanScope.of(context);
    setState(() => _trwa = true);
    final dane = {
      'rodzaj': _rodzaj,
      'pola': _zaznaczone.toList(),
      'opis': _opis.text.trim(),
      'tel': ?_telefon,
      'przylacze': ?s.przylacze?.id,
      if (_dolaczTest && s.ostatniTest != null)
        'raport_test': (s.proby.isEmpty ? [s.ostatniTest!] : s.proby).map((w) => w.doRaportu()).join('\n'),
      if (_dolaczTest && s.ostatniTest?.idObciazenia != null) 'obciazenie_id': s.ostatniTest!.idObciazenia,
      // dokładne czasy do serwisów tylko dla serwisu w EYE, klient ich nie widzi
      if (_dolaczTest && s.ostatniRanking != null) 'ranking': RankingSerwisow.doZgloszenia(s.ostatniRanking!),
      'zrodlo': 'aplikacja',
    };
    try {
      String nr;
      try {
        nr = await s.api.wyslijZgloszenie(s.token, dane);
      } on BladApi catch (e) {
        if (e.kod != 403 || (e.wymaganyPoziom ?? 0) < 3) rethrow;
        // np. usługa wstrzymana: EYE wymaga numeru z umowy
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            content: const Text('Do tego zgłoszenia potrzebujemy potwierdzenia numerem telefonu zapisanym w umowie.'),
            actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Dalej'))],
          ),
        );
        if (!await _podnies(3) || !mounted) return;
        nr = await s.api.wyslijZgloszenie(StanScope.of(context).token, dane);
      }
      if (!mounted) return;
      _opis.clear();
      _zaznaczone.clear();
      setState(() => _moje = _pobierzMoje());
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Kolory.zielony, size: 40),
          title: Text('Zgłoszenie $nr przyjęte'),
          content: const Text('Serwis skontaktuje się z Tobą pod podanym numerem. Status zobaczysz poniżej w „Moje zgłoszenia”.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
    } catch (e) {
      if (mounted) obsluzBlad(context, e);
    } finally {
      if (mounted) setState(() => _trwa = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StanScope.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      const WyborPrzylacza(),
      const Karta(
        kolor: Color(0xFFFFF8F1),
        child: Text('Zanim zgłosisz: sprawdź stan przyłącza w zakładce „Test łącza”. '
            'Często pomaga wyłączenie terminala i routera z prądu na 30 sekund.'),
      ),
      const Naglowek('Co się dzieje?'),
      Karta(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: RadioGroup<String>(
          groupValue: _rodzaj,
          onChanged: (v) => setState(() => _rodzaj = v!),
          child: Column(children: [
            for (final e in _rodzaje.entries) RadioListTile<String>(value: e.key, title: Text(e.value), dense: true),
          ]),
        ),
      ),
      const Naglowek('Szczegóły'),
      Karta(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          for (final e in _objawy.entries)
            CheckboxListTile(
              value: _zaznaczone.contains(e.key),
              title: Text(e.value),
              dense: true,
              onChanged: (v) => setState(() => v! ? _zaznaczone.add(e.key) : _zaznaczone.remove(e.key)),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _opis,
        maxLines: 4,
        maxLength: 1000,
        decoration: const InputDecoration(labelText: 'Opis problemu', hintText: 'Od kiedy, co dokładnie nie działa…', alignLabelWithHint: true),
      ),
      if (s.ostatniTest != null)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _dolaczTest,
          onChanged: (v) => setState(() => _dolaczTest = v!),
          title: const Text('Dołącz wynik testu prędkości'),
          subtitle: Text('${s.ostatniTest!.pobieranieMbps.toStringAsFixed(0)} / ${s.ostatniTest!.wysylanieMbps.toStringAsFixed(0)} Mb/s '
              'oraz szczegóły pomiarów dla serwisu'),
        ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _trwa ? null : _wyslij,
        icon: const Icon(Icons.send),
        label: Text(s.poziom < 2 ? 'Dalej: potwierdź telefon SMS-em' : 'Wyślij zgłoszenie'),
      ),
      const Naglowek('Moje zgłoszenia'),
      FutureBuilder<List<Zgloszenie>>(
        future: _moje,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Karta(child: Text('${snap.error}'));
          if (snap.data!.isEmpty) return const Karta(child: Text('Nie masz jeszcze zgłoszeń.'));
          return Card(
            child: Column(children: [
              for (final z in snap.data!)
                ListTile(
                  leading: Icon(z.status.startsWith('zamk') ? Icons.task_alt : Icons.pending_actions,
                      color: z.status.startsWith('zamk') ? Kolory.zielony : Kolory.pomarancz),
                  title: Text('${z.numer} · ${z.status}'),
                  subtitle: Text(z.opis, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: z.data == null ? null : Text('${z.data!.day}.${z.data!.month.toString().padLeft(2, '0')}'),
                ),
            ]),
          );
        },
      ),
      const SizedBox(height: 12),
      const KartaKontakt(),
    ]);
  }
}
