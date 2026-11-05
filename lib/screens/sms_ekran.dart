import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../widgets/wspolne.dart';

/// Potwierdzenie kodem SMS.
/// [rozszerzony] = false: poziom 2, dowolny numer kontaktowy (zgłoszenie awarii).
/// [rozszerzony] = true: poziom 3, numer zapisany w net47. Aplikacja nie podpowiada
/// numeru ani jego fragmentu; klient musi go wpisać sam.
class SmsEkran extends StatefulWidget {
  final bool rozszerzony;
  const SmsEkran({super.key, required this.rozszerzony});
  @override
  State<SmsEkran> createState() => _SmsEkranState();
}

class _SmsEkranState extends State<SmsEkran> {
  final _tel = TextEditingController();
  final _kod = TextEditingController();
  bool _wyslano = false;
  bool _trwa = false;

  Future<void> _wyslij() async {
    final cyfry = _tel.text.replaceAll(RegExp(r'\D'), '');
    if (cyfry.length < 9) {
      pokazKomunikat(context, 'Wpisz 9-cyfrowy numer telefonu.');
      return;
    }
    setState(() => _trwa = true);
    try {
      await StanScope.of(context).wyslijKod(_tel.text, rozszerzony: widget.rozszerzony);
      setState(() => _wyslano = true);
    } catch (e) {
      if (mounted) obsluzBlad(context, e);
    } finally {
      if (mounted) setState(() => _trwa = false);
    }
  }

  Future<void> _potwierdz() async {
    setState(() => _trwa = true);
    try {
      await StanScope.of(context).potwierdzKod(_kod.text);
      if (mounted) Navigator.of(context).pop(_tel.text);
    } catch (e) {
      if (mounted) obsluzBlad(context, e);
    } finally {
      if (mounted) setState(() => _trwa = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rozszerzony;
    return Scaffold(
      appBar: AppBar(title: Text(r ? 'Potwierdź numer z umowy' : 'Potwierdź telefon')),
      body: Waska(child: ListView(padding: const EdgeInsets.all(16), children: [
        Text(r
            ? 'Ta operacja wymaga numeru telefonu zapisanego w Twojej umowie. Wpisz go, a wyślemy na niego kod SMS.'
            : 'Podaj numer, pod którym serwis może się z Tobą skontaktować. Wyślemy na niego kod SMS.'),
        if (Config.demo)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Tryb pokazowy: kod 123456${r ? ', numer z umowy 600100200' : ''}.',
                style: const TextStyle(color: Colors.black54)),
          ),
        const SizedBox(height: 20),
        TextField(
          controller: _tel,
          enabled: !_wyslano,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d +]'))],
          // Celowo bez autofillHints przy poziomie 3: numer ma wpisać klient.
          autofillHints: r ? null : const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(labelText: 'Numer telefonu', prefixIcon: Icon(Icons.phone_android)),
        ),
        const SizedBox(height: 12),
        if (!_wyslano)
          FilledButton(onPressed: _trwa ? null : _wyslij, child: const Text('Wyślij kod'))
        else ...[
          TextField(
            controller: _kod,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Kod z SMS-a', prefixIcon: Icon(Icons.sms_outlined)),
            onSubmitted: (_) => _potwierdz(),
          ),
          FilledButton(onPressed: _trwa ? null : _potwierdz, child: const Text('Potwierdź')),
          TextButton(
            onPressed: _trwa ? null : () => setState(() => _wyslano = false),
            child: const Text('Zmień numer lub wyślij ponownie'),
          ),
        ],
        const SizedBox(height: 16),
        if (r)
          const Text('Nie pamiętasz, jaki numer jest w umowie? Zadzwoń do biura, sprawdzimy to po weryfikacji.',
              style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 12),
        const KartaKontakt(),
      ])),
    );
  }
}
