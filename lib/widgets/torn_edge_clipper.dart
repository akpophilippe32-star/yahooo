import 'dart:math';

import 'package:flutter/material.dart';

/// Découpe une image/zone avec un contour irrégulier façon
/// "sticker en papier déchiré", au lieu d'un rectangle net.
///
/// Utilisé pour les photos de l'écran d'accueil, plutôt qu'une carte
/// rectangulaire classique.
class TornEdgeClipper extends CustomClipper<Path> {
  final int seed;

  const TornEdgeClipper({this.seed = 1});

  @override
  Path getClip(Size size) {
    final random = Random(seed);
    const segmentLength = 16.0;
    const jitter = 5.0;

    final corners = [
      const Offset(0, 0),
      Offset(size.width, 0),
      Offset(size.width, size.height),
      Offset(0, size.height),
    ];

    final points = <Offset>[];

    for (var i = 0; i < corners.length; i++) {
      final start = corners[i];
      final end = corners[(i + 1) % corners.length];

      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final length = sqrt(dx * dx + dy * dy);

      if (length == 0) continue;

      final normalX = -dy / length;
      final normalY = dx / length;

      final segments = (length / segmentLength).round().clamp(2, 60);

      for (var s = 0; s < segments; s++) {
        final t = s / segments;
        final baseX = start.dx + dx * t;
        final baseY = start.dy + dy * t;
        final offset = (random.nextDouble() - 0.5) * 2 * jitter;

        points.add(
          Offset(baseX + normalX * offset, baseY + normalY * offset),
        );
      }
    }

    if (points.isEmpty) {
      return Path()..addRect(Offset.zero & size);
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}