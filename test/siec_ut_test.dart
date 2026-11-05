import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ut_abonent/services/iperf3.dart';
import 'package:ut_abonent/services/test_predkosci.dart';

void main() {
  test('test prędkości tylko w sieci UT: serwer iperf3 nieosiągalny = poza siecią', () async {
    expect(await TestPredkosci(iperf: [Iperf3(host: '127.0.0.1', port: 1)]).wSieciUT(), isFalse);
  });

  test('serwer iperf3 odpowiada = w sieci UT', () async {
    final serwer = await ServerSocket.bind('127.0.0.1', 0);
    serwer.listen((s) => s.destroy());
    expect(await TestPredkosci(iperf: [Iperf3(host: '127.0.0.1', port: 1), Iperf3(host: '127.0.0.1', port: serwer.port)]).wSieciUT(), isTrue);
    await serwer.close();
  });
}
