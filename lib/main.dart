import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api/api.dart';
import 'screens/awaria_ekran.dart';
import 'screens/routery_ekran.dart';
import 'screens/start_ekran.dart';
import 'screens/test_ekran.dart';
import 'screens/ustawienia_ekran.dart';
import 'services/stan_aplikacji.dart';
import 'widgets/aktualizacja.dart';
import 'widgets/logo_ut.dart';
import 'widgets/wspolne.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final stan = StanAplikacji(Api.utworz())..wczytaj();
  runApp(AplikacjaUT(stan: stan));
}

class Kolory {
  static const granat = Color(0xFF0B2545);
  static const pomarancz = Color(0xFFC2410C);
  static const zielony = Color(0xFF1F7A4D);
  static const tlo = Color(0xFFF6F8FB);
  static const ramka = Color(0xFFE3E8EF);
  static const tekst2 = Color(0xFF4A5563);
}

class AplikacjaUT extends StatelessWidget {
  final StanAplikacji stan;
  const AplikacjaUT({super.key, required this.stan});

  @override
  Widget build(BuildContext context) {
    final schemat = ColorScheme.fromSeed(
      seedColor: Kolory.granat,
      primary: Kolory.granat,
      secondary: Kolory.pomarancz,
      surface: Colors.white,
    );
    return StanScope(
      stan: stan,
      child: MaterialApp(
        title: 'UltraTech',
        debugShowCheckedModeBanner: false,
        locale: const Locale('pl'),
        supportedLocales: const [Locale('pl')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          fontFamily: 'Manrope',
          colorScheme: schemat,
          scaffoldBackgroundColor: Kolory.tlo,
          appBarTheme: const AppBarTheme(
              backgroundColor: Kolory.granat, foregroundColor: Colors.white, centerTitle: false),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Kolory.ramka)),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                backgroundColor: Kolory.pomarancz,
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
          navigationBarTheme: const NavigationBarThemeData(indicatorColor: Color(0xFFFDE9D7)),
        ),
        home: const Powloka(),
      ),
    );
  }
}

/// Główny układ z dolnym paskiem zakładek.
class Powloka extends StatefulWidget {
  const Powloka({super.key});
  @override
  State<Powloka> createState() => PowlokaState();
}

class PowlokaState extends State<Powloka> {
  int zakladka = 0;

  void przejdz(int i) => setState(() => zakladka = i);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => sprawdzAktualizacje(context));
  }

  static const _tytuly = ['UltraTech', 'Test łącza', 'Zgłoś awarię', 'Mój WiFi'];
  static const _pozycje = [
    (Icons.home_outlined, Icons.home, 'Start'),
    (Icons.speed_outlined, Icons.speed, 'Test łącza'),
    (Icons.report_problem_outlined, Icons.report_problem, 'Awaria'),
    (Icons.router_outlined, Icons.router, 'Mój WiFi'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: zakladka == 0
            ? Row(children: [
                const LogoUT(rozmiar: 32),
                const SizedBox(width: 10),
                const Text('UltraTech'),
              ])
            : Text(_tytuly[zakladka]),
        actions: [
          IconButton(
            tooltip: 'Konto i ustawienia',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const UstawieniaEkran())),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, c) {
        final tresc = IndexedStack(index: zakladka, children: [
          StartEkran(przejdz: przejdz),
          const TestEkran(),
          const AwariaEkran(),
          const RouteryEkran(),
        ]);
        // Panel web / tablet: boczne menu i treść o ograniczonej szerokości.
        if (c.maxWidth < 840) return tresc;
        return Row(children: [
          NavigationRail(
            selectedIndex: zakladka,
            onDestinationSelected: przejdz,
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.white,
            destinations: [
              for (final d in _pozycje)
                NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: tresc))),
        ]);
      }),
      bottomNavigationBar: MediaQuery.sizeOf(context).width >= 840
          ? null
          : NavigationBar(
              selectedIndex: zakladka,
              onDestinationSelected: przejdz,
              destinations: [
                for (final d in _pozycje)
                  NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
              ],
            ),
    );
  }
}
