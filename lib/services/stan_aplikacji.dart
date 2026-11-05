import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api.dart';
import '../api/models.dart';

/// Stan logowania i wybrane przyłącze. Token trzymany w bezpiecznym magazynie
/// telefonu (Keychain / Keystore). PIN nigdy nie jest zapisywany.
class StanAplikacji extends ChangeNotifier {
  final Api api;
  final FlutterSecureStorage _magazyn;
  StanAplikacji(this.api, {FlutterSecureStorage? magazyn})
      : _magazyn = magazyn ?? const FlutterSecureStorage();

  Sesja? _sesja;
  Przylacze? przylacze;
  WynikTestu? ostatniTest;
  /// Pomiary do polskich serwisów: tylko do zgłoszenia w EYE, klient widzi werdykt.
  List<({String host, int? ms})>? ostatniRanking;

  Sesja? get sesja => _sesja;
  bool get zalogowany => _sesja != null && !_wygasla;
  int get poziom => zalogowany ? _sesja!.poziom : 0;
  bool get _wygasla => _sesja?.wygasa != null && _sesja!.wygasa!.isBefore(DateTime.now());
  String get token => _sesja!.token;

  Future<void> zaloguj(String id, String pin) async {
    _sesja = await api.zaloguj(id.trim(), pin.trim());
    przylacze = _sesja!.przylacza.isEmpty ? null : _sesja!.przylacza.first;
    await _zapisz();
    notifyListeners();
  }

  Future<void> wyslijKod(String telefon, {required bool rozszerzony}) =>
      api.wyslijKodSms(token, telefon.replaceAll(RegExp(r'[^\d+]'), ''), rozszerzony ? 'rozszerzony' : 'zgloszenie');

  Future<void> potwierdzKod(String kod) async {
    _sesja = await api.potwierdzKodSms(_sesja!, kod.trim());
    await _zapisz();
    notifyListeners();
  }

  void wybierzPrzylacze(Przylacze p) {
    przylacze = p;
    notifyListeners();
  }

  void zapiszRanking(List<({String host, int? ms})>? r) {
    ostatniRanking = r;
    notifyListeners();
  }

  /// Próby porównawcze (Wi-Fi, kabel do routera, kabel do terminala) z tej sesji, do zgłoszenia.
  final proby = <WynikTestu>[];

  void zapiszTest(WynikTestu w) {
    ostatniTest = w;
    proby.removeWhere((p) => p.polaczenie == w.polaczenie);
    proby.add(w);
    notifyListeners();
  }

  Future<void> wyloguj() async {
    if (_sesja != null) await api.wyloguj(_sesja!.token);
    _sesja = null;
    przylacze = null;
    try {
      await _magazyn.delete(key: 'token');
    } catch (_) {}
    notifyListeners();
  }

  /// Wywoływane, gdy API zwróci 401: sesja wygasła po stronie EYE.
  void sesjaWygasla() {
    _sesja = null;
    notifyListeners();
  }

  Future<void> _zapisz() async {
    // W przeglądarce (panel web) token żyje tylko w pamięci karty: bez localStorage.
    if (kIsWeb) return;
    // Zapisujemy tylko token i poziom; przy następnym starcie i tak sprawdzamy go w EYE.
    try {
      await _magazyn.write(key: 'token', value: '${_sesja!.poziom}|${_sesja!.wygasa?.toIso8601String() ?? ''}|${_sesja!.token}');
    } catch (_) {}
  }

  Future<void> wczytaj() async {
    if (kIsWeb) return;
    try {
      final v = await _magazyn.read(key: 'token');
      if (v == null) return;
      final cz = v.split('|');
      if (cz.length < 3) return;
      final s = Sesja(token: cz.sublist(2).join('|'), poziom: int.tryParse(cz[0]) ?? 1, wygasa: DateTime.tryParse(cz[1]));
      if (s.wygasa != null && s.wygasa!.isBefore(DateTime.now())) return;
      _sesja = s;
      notifyListeners();
    } catch (_) {}
  }
}
