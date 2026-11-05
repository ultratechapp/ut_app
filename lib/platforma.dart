import 'package:flutter/foundation.dart';

/// Windows, macOS albo Linux (aplikacja na komputer).
bool get jestDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Komputer: panel w przeglądarce albo aplikacja desktop. Wpływa na podpowiedzi (kabel zamiast sieci komórkowej).
bool get naKomputerze => kIsWeb || jestDesktop;

/// Klucz w manifeście wersja.json.
String get kluczPlatformy => switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.windows => 'windows',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.linux => 'linux',
      _ => 'android',
    };
