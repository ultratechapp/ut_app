import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../widgets/wspolne.dart';

/// Poziom 1: ID klienta z net47 (z faktury lub umowy) + PIN e-BOK.
class LogowanieEkran extends StatefulWidget {
  const LogowanieEkran({super.key});
  @override
  State<LogowanieEkran> createState() => _LogowanieEkranState();
}

class _LogowanieEkranState extends State<LogowanieEkran> {
  final _id = TextEditingController();
  final _pin = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _trwa = false;
  bool _pokazPin = false;

  Future<void> _zaloguj() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _trwa = true);
    try {
      await StanScope.of(context).zaloguj(_id.text, _pin.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) pokazKomunikat(context, e);
    } finally {
      if (mounted) setState(() => _trwa = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logowanie')),
      body: Waska(child: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Podaj ID klienta (jest na fakturze i w umowie) oraz PIN do e-BOK.'),
          if (Config.demo)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Tryb pokazowy: dowolne ID i PIN 1234. ID 999: dwa przyłącza, 1002: usługa wstrzymana, 1003: brak połączenia.',
                  style: TextStyle(color: Colors.black54)),
            ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _id,
            decoration: const InputDecoration(labelText: 'ID klienta', prefixIcon: Icon(Icons.badge_outlined)),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Wpisz ID klienta' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pin,
            obscureText: !_pokazPin,
            decoration: InputDecoration(
              labelText: 'PIN e-BOK',
              prefixIcon: const Icon(Icons.pin_outlined),
              suffixIcon: IconButton(
                tooltip: _pokazPin ? 'Ukryj PIN' : 'Pokaż PIN',
                icon: Icon(_pokazPin ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _pokazPin = !_pokazPin),
              ),
            ),
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _zaloguj(),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Wpisz PIN' : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _trwa ? null : _zaloguj,
            child: _trwa
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Zaloguj'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => otworzLink(Config.ebokUrl),
            child: const Text('Nie pamiętasz PIN-u? Przejdź do e-BOK'),
          ),
          const SizedBox(height: 12),
          const KartaKontakt(),
          const SizedBox(height: 12),
          const Text(
            'Aplikacja nie zapisuje PIN-u. Po zalogowaniu widzisz tylko stan łącza i swoje zgłoszenia, bez danych finansowych.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ]),
      )),
    );
  }
}
