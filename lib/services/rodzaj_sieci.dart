import 'dart:io' show Process;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../api/models.dart';

/// Rozpoznanie Wi-Fi / kabel / komórkowe z systemu i (gdzie się da) parametry Wi-Fi.
/// Wynik idzie tylko do raportu w EYE, nie na ekran.
/// - Android: typ z ConnectivityManager, sygnał / link speed / częstotliwość z WifiManager (MainActivity.kt),
/// - iOS: tylko typ (NWPathMonitor przez connectivity_plus),
/// - Windows: `netsh wlan show interfaces`, Linux: `nmcli`, macOS: `system_profiler SPAirPortDataType`,
/// - przeglądarka: zwykle brak danych (rodzaj „nieznany”).
class RodzajSieci {
  static const _kanal = MethodChannel('pl.net.ultratech/wifi');

  static Future<Polaczenie> wykryj() async {
    String rodzaj = 'nieznany';
    try {
      final typy = await Connectivity().checkConnectivity();
      if (typy.contains(ConnectivityResult.ethernet)) {
        rodzaj = 'kabel_router';
      } else if (typy.contains(ConnectivityResult.wifi)) {
        rodzaj = 'wifi';
      } else if (typy.contains(ConnectivityResult.mobile)) {
        rodzaj = 'komorkowe';
      }
    } catch (_) {}
    if (kIsWeb) return Polaczenie(rodzaj: rodzaj, zrodlo: rodzaj == 'nieznany' ? 'brak' : 'przegladarka');
    if (rodzaj != 'wifi') return Polaczenie(rodzaj: rodzaj, zrodlo: 'system');
    try {
      final (dbm, rate, mhz) = await _parametryWifi();
      return Polaczenie(rodzaj: 'wifi', zrodlo: 'system', sygnalDbm: dbm, rateMbps: rate, pasmo: pasmo(mhz));
    } catch (_) {
      return const Polaczenie(rodzaj: 'wifi', zrodlo: 'system');
    }
  }

  static String? pasmo(int? mhz) => mhz == null
      ? null
      : mhz >= 5925
          ? '6 GHz'
          : mhz >= 4900
              ? '5 GHz'
              : '2,4 GHz';

  static Future<(int?, int?, int?)> _parametryWifi() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final m = await _kanal.invokeMapMethod<String, dynamic>('parametry');
        return (m?['rssi'] as int?, m?['linkSpeed'] as int?, m?['czestotliwosc'] as int?);
      case TargetPlatform.windows:
        return parsujNetsh((await Process.run('netsh', ['wlan', 'show', 'interfaces'])).stdout.toString());
      case TargetPlatform.linux:
        final r = await Process.run('nmcli', ['-t', '-f', 'ACTIVE,SIGNAL,RATE,FREQ', 'dev', 'wifi']);
        return parsujNmcli(r.stdout.toString());
      case TargetPlatform.macOS:
        final r = await Process.run('system_profiler', ['SPAirPortDataType']);
        return parsujMac(r.stdout.toString());
      default:
        return (null, null, null);
    }
  }

  static int? _int(String? s) => s == null ? null : int.tryParse(RegExp(r'-?\d+').firstMatch(s)?.group(0) ?? '');

  /// Windows: Signal w % → dBm ≈ %/2 − 100; Receive rate (Mbps); Channel → pasmo.
  @visibleForTesting
  static (int?, int?, int?) parsujNetsh(String t) {
    String? pole(String nazwa) => RegExp('^\\s*$nazwa\\s*:\\s*(.+)\$', multiLine: true, caseSensitive: false).firstMatch(t)?.group(1);
    final proc = _int(pole('Signal'));
    final kanal = _int(pole('Channel'));
    return (
      proc == null ? null : (proc / 2 - 100).round(),
      _int(pole('Receive rate \\(Mbps\\)')),
      kanal == null ? null : (kanal > 14 ? 5200 : 2437),
    );
  }

  /// Linux nmcli -t: "yes:72:540 Mbit/s:5180 MHz" (SIGNAL w %).
  @visibleForTesting
  static (int?, int?, int?) parsujNmcli(String t) {
    for (final l in t.split('\n')) {
      final p = l.split(':');
      if (p.length >= 4 && (p[0] == 'yes' || p[0] == 'tak')) {
        final proc = _int(p[1]);
        return (proc == null ? null : (proc / 2 - 100).round(), _int(p[2]), _int(p[3]));
      }
    }
    return (null, null, null);
  }

  /// macOS: "Signal / Noise: -58 dBm / -92 dBm", "Transmit Rate: 866", "Channel: 36 (5GHz, 80MHz)".
  @visibleForTesting
  static (int?, int?, int?) parsujMac(String t) {
    final biezaca = t.split('Other Local Wi-Fi Networks').first;
    final sygnal = RegExp(r'Signal / Noise:\s*(-?\d+)').firstMatch(biezaca)?.group(1);
    final rate = RegExp(r'Transmit Rate:\s*(\d+)').firstMatch(biezaca)?.group(1);
    final kanal = RegExp(r'Channel:\s*\d+\s*\((\d)').firstMatch(biezaca)?.group(1);
    return (_int(sygnal), _int(rate), kanal == null ? null : (kanal == '5' ? 5200 : kanal == '6' ? 6000 : 2437));
  }
}
