import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config.dart';
import '../widgets/aktualizacja.dart';
import '../widgets/wspolne.dart';
import 'logowanie_ekran.dart';

class UstawieniaEkran extends StatelessWidget {
  const UstawieniaEkran({super.key});

  static const _poziomy = {
    1: 'zalogowany (ID i PIN)',
    2: 'telefon potwierdzony SMS-em',
    3: 'numer z umowy potwierdzony',
  };

  @override
  Widget build(BuildContext context) {
    final s = StanScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Konto i ustawienia')),
      body: Waska(child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Column(children: [
            if (s.zalogowany) ...[
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('Jesteś zalogowany'),
                subtitle: Text('Poziom dostępu: ${_poziomy[s.poziom] ?? s.poziom}'),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Wyloguj'),
                onTap: () async {
                  await s.wyloguj();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Zaloguj się'),
                subtitle: const Text('ID klienta i PIN e-BOK'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LogowanieEkran())),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('e-BOK (faktury, płatności)'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => otworzLink(Config.ebokUrl),
            ),
            const ListTile(
              leading: Icon(Icons.call_outlined),
              title: Text('Biuro obsługi klienta'),
              subtitle: Text(Config.telefonBiuroLadny),
              onTap: zadzwonDoBiura,
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text(Config.email),
              onTap: () => otworzLink('mailto:${Config.email}'),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('ultratech.net.pl'),
              onTap: () => otworzLink(Config.stronaUrl),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(children: [
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (_, i) => ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Wersja aplikacji'),
                subtitle: Text(i.hasData ? '${i.data!.version} (${i.data!.buildNumber})${Config.demo ? ' · tryb pokazowy' : ''}' : '…'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.system_update_outlined),
              title: const Text('Sprawdź aktualizacje'),
              onTap: () => sprawdzAktualizacje(context, reczne: true),
            ),
          ]),
        ),
      ])),
    );
  }
}
