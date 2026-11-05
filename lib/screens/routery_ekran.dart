import 'package:flutter/material.dart';

import '../api/models.dart';
import '../main.dart';
import '../widgets/wspolne.dart';
import 'sms_ekran.dart';

/// Konfiguracja routerów WiFi mesh od UltraTech (Uplink AX34H, V-SOL i inne).
/// Oprogramowanie routerów powstaje w projekcie WiFi_openwrt; ten ekran woła
/// zaślepki API /klient/routery/... (opis w docs/API_routery.md).
class RouteryEkran extends StatelessWidget {
  const RouteryEkran({super.key});
  @override
  Widget build(BuildContext context) => const WymagaPoziomu(
        poziom: 1,
        powod: 'Zaloguj się, aby zobaczyć swoje routery WiFi i zmienić ustawienia sieci.',
        child: _Routery(),
      );
}

class _Routery extends StatefulWidget {
  const _Routery();
  @override
  State<_Routery> createState() => _RouteryState();
}

class _RouteryState extends State<_Routery> {
  Future<(SiecWifi, List<RouterMesh>)>? _dane;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dane ??= _pobierz();
  }

  Future<(SiecWifi, List<RouterMesh>)> _pobierz() async {
    final s = StanScope.of(context);
    final w = await Future.wait([s.api.siecWifi(s.token), s.api.routery(s.token)]);
    return (w[0] as SiecWifi, w[1] as List<RouterMesh>);
  }

  void _odswiez() => setState(() => _dane = _pobierz());

  /// Zmiany ustawień wymagają potwierdzenia telefonu (poziom 2).
  Future<bool> _potwierdzone() async {
    if (StanScope.of(context).poziom >= 2) return true;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SmsEkran(rozszerzony: false)));
    return mounted && StanScope.of(context).poziom >= 2;
  }

  Future<void> _wykonaj(Future<void> Function() f, String ok) async {
    if (!await _potwierdzone()) return;
    try {
      await f();
      if (mounted) {
        pokazKomunikat(context, ok);
        _odswiez();
      }
    } catch (e) {
      if (mounted) obsluzBlad(context, e);
    }
  }

  Future<void> _edytujWifi(SiecWifi w) async {
    final ssid = TextEditingController(text: w.ssid);
    final haslo = TextEditingController();
    final wynik = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Nazwa i hasło WiFi', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: ssid, maxLength: 32, decoration: const InputDecoration(labelText: 'Nazwa sieci (SSID)')),
          TextField(
              controller: haslo,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nowe hasło (min. 8 znaków)', helperText: 'Zostaw puste, aby nie zmieniać')),
          const SizedBox(height: 8),
          const Text('Po zapisaniu wszystkie urządzenia rozłączą się z WiFi i trzeba je połączyć ponownie.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Zapisz na wszystkich routerach')),
        ]),
      ),
    );
    if (wynik != true || !mounted) return;
    if (ssid.text.trim().isEmpty || (haslo.text.isNotEmpty && haslo.text.length < 8)) {
      pokazKomunikat(context, 'Nazwa nie może być pusta, a hasło musi mieć co najmniej 8 znaków.');
      return;
    }
    final s = StanScope.of(context);
    await _wykonaj(
        () => s.api.zapiszSiecWifi(s.token, ssid: ssid.text.trim(), haslo: haslo.text.isEmpty ? null : haslo.text),
        'Zapisano. Routery wprowadzą zmiany w ciągu minuty.');
  }

  Future<void> _akcja(RouterMesh r, String a) async {
    final s = StanScope.of(context);
    switch (a) {
      case 'nazwa':
        final t = TextEditingController(text: r.nazwa);
        final nowa = await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Nazwa urządzenia'),
            content: TextField(controller: t, autofocus: true, decoration: const InputDecoration(hintText: 'np. Salon, Piętro')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anuluj')),
              FilledButton(onPressed: () => Navigator.pop(c, t.text.trim()), child: const Text('Zapisz')),
            ],
          ),
        );
        if (nowa != null && nowa.isNotEmpty) {
          await _wykonaj(() => s.api.zmienNazweRoutera(s.token, r.id, nowa), 'Zmieniono nazwę.');
        }
      case 'restart':
        await _wykonaj(() => s.api.restartRoutera(s.token, r.id), 'Router „${r.nazwa}” uruchamia się ponownie (ok. 2 minuty).');
      case 'firmware':
        await _wykonaj(() => s.api.aktualizujFirmware(s.token, r.id),
            'Aktualizacja rozpoczęta. Nie wyłączaj routera z prądu przez 5 minut.');
    }
  }

  Future<void> _dodajWezel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Dodaj punkt mesh'),
        content: const Text('1. Podłącz nowy router do prądu w pobliżu głównego.\n'
            '2. Poczekaj, aż dioda zacznie migać (ok. 1 minuty).\n'
            '3. Naciśnij „Paruj”. Główny router przez 2 minuty będzie szukał nowego punktu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Paruj')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final s = StanScope.of(context);
    await _wykonaj(() => s.api.parujWezel(s.token), 'Szukam nowego punktu. Odśwież listę za 2 minuty.');
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _odswiez();
        await _dane!.catchError((_) => (SiecWifi(ssid: ''), <RouterMesh>[]));
      },
      child: FutureBuilder<(SiecWifi, List<RouterMesh>)>(
        future: _dane,
        builder: (context, snap) {
          final dzieci = <Widget>[
            const Karta(
              kolor: Color(0xFFF1F4F8),
              child: Row(children: [
                Icon(Icons.construction, color: Kolory.tekst2),
                SizedBox(width: 10),
                Expanded(
                    child: Text('Funkcja w przygotowaniu. Zadziała na routerach mesh od UltraTech z nowym oprogramowaniem.',
                        style: TextStyle(color: Kolory.tekst2))),
              ]),
            ),
          ];
          if (snap.connectionState != ConnectionState.done) {
            dzieci.add(const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())));
          } else if (snap.hasError) {
            dzieci.add(Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Karta(child: Text('Nie udało się połączyć z routerami.\n${snap.error}')),
            ));
          } else {
            final (wifi, routery) = snap.data!;
            dzieci.addAll([
              const Naglowek('Sieć WiFi'),
              Karta(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(Icons.wifi, color: Kolory.granat),
                    const SizedBox(width: 10),
                    Expanded(child: Text(wifi.ssid, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: () => _edytujWifi(wifi), icon: const Icon(Icons.edit), label: const Text('Zmień nazwę lub hasło')),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sieć dla gości'),
                    subtitle: Text(wifi.gosc ? (wifi.ssidGosc ?? 'włączona') : 'wyłączona'),
                    value: wifi.gosc,
                    onChanged: (v) {
                      final s = StanScope.of(context);
                      _wykonaj(() => s.api.zapiszSiecWifi(s.token, ssid: wifi.ssid, gosc: v),
                          v ? 'Włączono sieć dla gości.' : 'Wyłączono sieć dla gości.');
                    },
                  ),
                ]),
              ),
              const Naglowek('Urządzenia mesh'),
              Card(
                child: Column(children: [
                  for (final r in routery) ...[
                    ListTile(
                      leading: Icon(r.glowny ? Icons.router : Icons.settings_input_antenna,
                          color: r.online ? Kolory.zielony : const Color(0xFFB42318)),
                      title: Text('${r.nazwa}${r.glowny ? ' (główny)' : ''}'),
                      subtitle: Text([
                        r.model,
                        r.online ? 'online' : 'offline',
                        '${r.klienci} urządz.',
                        if (r.jakoscPolaczenia != null) 'łącze mesh: ${r.jakoscPolaczenia}',
                        if (r.nowyFirmware != null) 'dostępna aktualizacja',
                      ].join(' · ')),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Opcje',
                        onSelected: (a) => _akcja(r, a),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'nazwa', child: Text('Zmień nazwę')),
                          const PopupMenuItem(value: 'restart', child: Text('Uruchom ponownie')),
                          if (r.nowyFirmware != null)
                            PopupMenuItem(value: 'firmware', child: Text('Aktualizuj do ${r.nowyFirmware}')),
                        ],
                      ),
                    ),
                    if (r != routery.last) const Divider(height: 1),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _dodajWezel, icon: const Icon(Icons.add), label: const Text('Dodaj punkt mesh')),
            ]);
          }
          return ListView(padding: const EdgeInsets.all(16), children: dzieci);
        },
      ),
    );
  }
}
