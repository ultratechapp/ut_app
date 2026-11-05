import 'package:flutter/material.dart';

import '../api/models.dart';
import '../main.dart';
import '../widgets/wspolne.dart';

/// Strona główna: aktualności serwisowe i promocyjne + szybkie przyciski.
class StartEkran extends StatefulWidget {
  final void Function(int) przejdz;
  const StartEkran({super.key, required this.przejdz});
  @override
  State<StartEkran> createState() => _StartEkranState();
}

class _StartEkranState extends State<StartEkran> {
  Future<List<Komunikat>>? _lista;
  String _filtr = 'wszystkie';
  String? _tokenPrzyPobraniu;

  void _pobierz() {
    final stan = StanScope.of(context);
    _tokenPrzyPobraniu = stan.zalogowany ? stan.token : null;
    _lista = stan.api.komunikaty(token: _tokenPrzyPobraniu).then(_sortuj);
  }

  List<Komunikat> _sortuj(List<Komunikat> l) {
    final teraz = DateTime.now();
    final aktualne = l.where((k) => k.doKiedy == null || k.doKiedy!.isAfter(teraz) || k.typ == 'awaria').toList();
    aktualne.sort((a, b) {
      if (a.przypiety != b.przypiety) return a.przypiety ? -1 : 1;
      if (a.priorytet != b.priorytet) return b.priorytet.compareTo(a.priorytet);
      return (b.zaktualizowano ?? DateTime(2000)).compareTo(a.zaktualizowano ?? DateTime(2000));
    });
    return aktualne;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stan = StanScope.of(context);
    // Po zalogowaniu pobieramy też komunikaty dla okolicy klienta.
    final t = stan.zalogowany ? stan.token : null;
    if (_lista == null || t != _tokenPrzyPobraniu) _pobierz();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(_pobierz);
        await _lista!.catchError((_) => <Komunikat>[]);
      },
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _SzybkiePrzyciski(przejdz: widget.przejdz),
        const Naglowek('Aktualności'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in const [('wszystkie', 'Wszystkie'), ('serwis', 'Serwisowe'), ('promocja', 'Promocje')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f.$2),
                  selected: _filtr == f.$1,
                  onSelected: (_) => setState(() => _filtr = f.$1),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Komunikat>>(
          future: _lista,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
            }
            if (s.hasError) {
              return Karta(
                  child: Text('Nie udało się pobrać aktualności. Przeciągnij w dół, aby spróbować ponownie.\n\n${s.error}'));
            }
            final lista = s.data!.where((k) => switch (_filtr) {
                  'serwis' => k.serwisowy,
                  'promocja' => !k.serwisowy,
                  _ => true,
                });
            if (lista.isEmpty) return const Karta(child: Text('Brak aktualności w tej kategorii.'));
            return Column(children: [
              for (final k in lista) Padding(padding: const EdgeInsets.only(bottom: 10), child: KartaKomunikatu(k)),
            ]);
          },
        ),
      ]),
    );
  }
}

class _SzybkiePrzyciski extends StatelessWidget {
  final void Function(int) przejdz;
  const _SzybkiePrzyciski({required this.przejdz});

  @override
  Widget build(BuildContext context) {
    Widget kafel(IconData ik, String t, Color kolor, VoidCallback f) => Expanded(
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Kolory.ramka)),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: f,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                child: Column(children: [
                  Icon(ik, color: kolor, size: 28),
                  const SizedBox(height: 6),
                  Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        );
    return Row(children: [
      kafel(Icons.speed, 'Test\nłącza', Kolory.granat, () => przejdz(1)),
      const SizedBox(width: 8),
      kafel(Icons.report_problem_outlined, 'Zgłoś\nawarię', Kolory.pomarancz, () => przejdz(2)),
      const SizedBox(width: 8),
      kafel(Icons.router_outlined, 'Mój\nWiFi', Kolory.zielony, () => przejdz(3)),
      const SizedBox(width: 8),
      kafel(Icons.call_outlined, 'Zadzwoń\ndo biura', Kolory.tekst2, zadzwonDoBiura),
    ]);
  }
}

class KartaKomunikatu extends StatelessWidget {
  final Komunikat k;
  const KartaKomunikatu(this.k, {super.key});

  static (IconData, Color, String) styl(String typ) => switch (typ) {
        'awaria' => (Icons.warning_amber_rounded, const Color(0xFFB42318), 'Awaria'),
        'prace_planowe' => (Icons.build_outlined, const Color(0xFFB54708), 'Prace planowe'),
        'promocja' => (Icons.local_offer_outlined, Kolory.zielony, 'Promocja'),
        _ => (Icons.info_outline, Kolory.granat, 'Informacja'),
      };

  String _okres() {
    String f(DateTime d) =>
        '${d.day}.${d.month.toString().padLeft(2, '0')} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    if (k.od == null) return '';
    return k.doKiedy == null ? 'od ${f(k.od!)}' : '${f(k.od!)} – ${f(k.doKiedy!)}';
  }

  @override
  Widget build(BuildContext context) {
    final (ikona, kolor, etykieta) = styl(k.typ);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: k.link == null ? null : () => otworzLink(k.link!),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(ikona, color: kolor, size: 20),
              const SizedBox(width: 6),
              Text(etykieta, style: TextStyle(color: kolor, fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              if (k.przypiety) const Icon(Icons.push_pin, size: 16, color: Kolory.tekst2),
            ]),
            const SizedBox(height: 8),
            Text(k.tytul, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (_okres().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_okres(), style: const TextStyle(color: Kolory.tekst2, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 6),
            Text(k.tresc),
            if (k.link != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Szczegóły →', style: TextStyle(color: Kolory.pomarancz, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
      ),
    );
  }
}
