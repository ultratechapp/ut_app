import 'dart:math';

import 'package:flutter/material.dart';

/// Logo UltraTech rysowane wektorowo: nieprzezroczysta pomarańczowa kula i białe litery.
/// Plik logo-UT.png ze strony ma przezroczyste litery i 65 px, więc na granatowym pasku wyglądał źle.
/// Geometria (ułamki średnicy) jest ta sama co w tool/logo_ut.py, z którego powstają ikony aplikacji.
class LogoUT extends StatelessWidget {
  final double rozmiar;
  const LogoUT({super.key, this.rozmiar = 32});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'UltraTech',
        image: true,
        child: CustomPaint(size: Size.square(rozmiar), painter: _LogoPainter()),
      );
}

class _LogoPainter extends CustomPainter {
  static const _jasny = Color(0xFFF7A640);
  static const _ciemny = Color(0xFFE25C08);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final kolo = Rect.fromLTWH(0, 0, s, s);
    canvas.drawOval(
      kolo,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_jasny, _ciemny],
        ).createShader(kolo),
    );
    // blask u góry po lewej
    canvas.drawOval(
      kolo,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.56),
          radius: 0.7,
          colors: [Colors.white.withValues(alpha: 0.32), Colors.white.withValues(alpha: 0)],
        ).createShader(kolo),
    );
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05 * s
      ..strokeCap = StrokeCap.round;
    void linia(double x1, double y1, double x2, double y2) => canvas.drawLine(Offset(x1 * s, y1 * s), Offset(x2 * s, y2 * s), p);
    linia(0.205, 0.285, 0.205, 0.44); // U
    canvas.drawArc(Rect.fromCircle(center: Offset(0.385 * s, 0.44 * s), radius: 0.18 * s), pi / 2, pi / 2, false, p);
    linia(0.385, 0.62, 0.40, 0.62);
    linia(0.455, 0.285, 0.455, 0.62); // L
    linia(0.455, 0.62, 0.52, 0.62);
    linia(0.53, 0.40, 0.84, 0.40); // T
    linia(0.685, 0.465, 0.685, 0.765);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
