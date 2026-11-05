import 'package:flutter/material.dart';

import '../services/aktualizacje.dart';
import 'wspolne.dart';

/// Sprawdza aktualizację i pokazuje okno. Wymaganej aktualizacji nie da się pominąć.
Future<void> sprawdzAktualizacje(BuildContext context, {bool reczne = false}) async {
  NowaWersja? w;
  try {
    w = await Aktualizacje.sprawdz(wymus: reczne);
  } catch (_) {
    if (reczne && context.mounted) pokazKomunikat(context, 'Nie udało się sprawdzić aktualizacji.');
    return;
  }
  if (!context.mounted) return;
  if (w == null) {
    if (reczne) pokazKomunikat(context, 'Masz najnowszą wersję aplikacji.');
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: !w.wymagana,
    builder: (_) => _OknoAktualizacji(w!),
  );
}

class _OknoAktualizacji extends StatefulWidget {
  final NowaWersja w;
  const _OknoAktualizacji(this.w);
  @override
  State<_OknoAktualizacji> createState() => _OknoAktualizacjiState();
}

class _OknoAktualizacjiState extends State<_OknoAktualizacji> {
  int? _procent;
  String? _blad;

  Future<void> _instaluj() async {
    setState(() {
      _procent = 0;
      _blad = null;
    });
    try {
      await for (final p in Aktualizacje.instaluj(widget.w)) {
        if (mounted) setState(() => _procent = p);
      }
    } catch (e) {
      if (mounted) setState(() => _blad = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.w;
    return PopScope(
      canPop: !w.wymagana,
      child: AlertDialog(
        title: Text(w.wymagana ? 'Wymagana aktualizacja' : 'Nowa wersja ${w.wersja}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (w.wymagana) const Text('Ta wersja aplikacji przestała działać z systemem UltraTech. Zainstaluj nową wersję.\n'),
          if (w.zmiany.isNotEmpty) Text(w.zmiany),
          if (_procent != null) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _procent! / 100),
            const SizedBox(height: 4),
            Text(_procent! >= 100 ? 'Otwieram instalator…' : 'Pobieranie: $_procent%'),
          ],
          if (_blad != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_blad!, style: const TextStyle(color: Colors.red))),
        ]),
        actions: [
          if (!w.wymagana) TextButton(onPressed: () => Navigator.pop(context), child: const Text('Później')),
          FilledButton(
            onPressed: _procent != null && _blad == null && _procent! < 100 ? null : _instaluj,
            child: Text(w.apk != null ? 'Pobierz i zainstaluj' : (w.pobierz != null ? 'Pobierz nową wersję' : 'Aktualizuj')),
          ),
        ],
      ),
    );
  }
}
