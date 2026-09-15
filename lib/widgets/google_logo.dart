import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reproduction du logo "G" multicolore de Google, dessinée
/// localement (CustomPainter) plutôt que chargée depuis une image
/// réseau — sur Flutter Web, les images externes sont souvent
/// bloquées par les restrictions CORS du serveur qui les héberge,
/// ce qui faisait échouer le chargement et retomber sur l'icône
/// générique de repli.
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  static double _deg(double degrees) => degrees * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final strokeWidth = radius * 0.42;
    final ringRadius = radius - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: ringRadius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Anneau divisé en 4 arcs colorés, avec un petit espace à
    // droite (vers 3h) où vient se raccrocher la barre centrale.
    paint.color = const Color(0xFF4285F4); // bleu
    canvas.drawArc(rect, _deg(8), _deg(92), false, paint);

    paint.color = const Color(0xFF34A853); // vert
    canvas.drawArc(rect, _deg(100), _deg(88), false, paint);

    paint.color = const Color(0xFFFBBC05); // jaune
    canvas.drawArc(rect, _deg(188), _deg(88), false, paint);

    paint.color = const Color(0xFFEA4335); // rouge
    canvas.drawArc(rect, _deg(276), _deg(76), false, paint);

    // Barre centrale bleue (la traverse du "G").
    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - strokeWidth * 0.08,
        center.dy - strokeWidth * 0.26,
        radius - center.dx + strokeWidth * 0.08 + strokeWidth * 0.1,
        strokeWidth * 0.52,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}