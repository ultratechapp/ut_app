import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../config.dart';
import '../screens/logowanie_ekran.dart';
import '../screens/sms_ekran.dart';
import '../services/stan_aplikacji.dart';

/// Udostępnia stan aplikacji wszystkim ekranom i przebudowuje je po zmianie logowania.
class StanScope extends InheritedNotifier<StanAplikacji> {
  const StanScope({super.key, required StanAplikacji stan, required super.child}) : super(notifier: stan);
  static StanAplikacji of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StanScope>()!.notifier!;
}

Future<void> zadzwonDoBiura() => launchUrl(Uri.parse('tel:${Config.telefonBiuro}'));
Future<void> otworzLink(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

void pokazKomunikat(BuildContext context, Object blad) {
  final tekst = blad is BladApi ? blad.komunikat : '$blad'.replaceFirst('Exception: ', '');
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(tekst), behavior: SnackBarBehavior.floating));
}

/// Obsługa błędu 401 (sesja wygasła) w jednym miejscu.
void obsluzBlad(BuildContext context, Object blad) {
  if (blad is BladApi && blad.kod == 401 && StanScope.of(context).zalogowany) {
    StanScope.of(context).sesjaWygasla();
  }
  pokazKomunikat(context, blad);
}

class Karta extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? kolor;
  const Karta({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.kolor});
  @override
  Widget build(BuildContext context) =>
      Card(color: kolor, child: Padding(padding: padding, child: child));
}

class Naglowek extends StatelessWidget {
  final String tekst;
  const Naglowek(this.tekst, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(tekst, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
}

/// Pokazuje [child] tylko, gdy klient jest zalogowany na co najmniej [poziom].
/// Poziom 1: ID klienta + PIN. Poziom 2: kod SMS na dowolny numer.
/// Poziom 3: kod SMS na numer z net47, wpisany bez podpowiedzi.
class WymagaPoziomu extends StatelessWidget {
  final int poziom;
  final String powod;
  final Widget child;
  const WymagaPoziomu({super.key, required this.poziom, required this.powod, required this.child});

  @override
  Widget build(BuildContext context) {
    final stan = StanScope.of(context);
    if (stan.poziom >= poziom) return child;
    final potrzebaLogowania = !stan.zalogowany;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Karta(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(potrzebaLogowania ? Icons.lock_outline : Icons.sms_outlined, size: 36, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(potrzebaLogowania ? 'Zaloguj się' : 'Potwierdź numer telefonu',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(powod),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => potrzebaLogowania
                  ? Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LogowanieEkran()))
                  : Navigator.of(context).push(MaterialPageRoute(builder: (_) => SmsEkran(rozszerzony: poziom >= 3))),
              child: Text(potrzebaLogowania ? 'Zaloguj ID klienta i PIN-em' : 'Wyślij kod SMS'),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      const KartaKontakt(),
    ]);
  }
}

class KartaKontakt extends StatelessWidget {
  const KartaKontakt({super.key});
  @override
  Widget build(BuildContext context) => Karta(
        child: Row(children: [
          const Icon(Icons.support_agent),
          const SizedBox(width: 12),
          const Expanded(child: Text('Wolisz porozmawiać? Biuro obsługi klienta')),
          TextButton(onPressed: zadzwonDoBiura, child: const Text(Config.telefonBiuroLadny)),
        ]),
      );
}

/// Wybór przyłącza, gdy klient (np. gmina, szkoła) ma kilka adresów pod jednym ID.
class WyborPrzylacza extends StatelessWidget {
  const WyborPrzylacza({super.key});
  @override
  Widget build(BuildContext context) {
    final stan = StanScope.of(context);
    final lista = stan.sesja?.przylacza ?? const [];
    if (lista.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: stan.przylacze?.id,
        decoration: const InputDecoration(labelText: 'Przyłącze'),
        items: [for (final p in lista) DropdownMenuItem(value: p.id, child: Text(p.adres))],
        onChanged: (id) => stan.wybierzPrzylacze(lista.firstWhere((p) => p.id == id)),
      ),
    );
  }
}

/// Na szerokim ekranie (komputer, panel web) formularze nie rozciągają się na całą szerokość.
class Waska extends StatelessWidget {
  final Widget child;
  final double maks;
  const Waska({super.key, required this.child, this.maks = 560});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maks), child: child),
      );
}
