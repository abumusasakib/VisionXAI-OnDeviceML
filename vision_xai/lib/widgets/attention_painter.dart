import 'dart:math';
import 'package:flutter/material.dart';

class AttentionPainter extends CustomPainter {
  final List<double> weights;

  AttentionPainter(this.weights);

  /// Helper to convert a normalized value [0.0, 1.0] to a Jet Color representation.
  Color getJetColor(double value) {
    value = value.clamp(0.0, 1.0);
    double r = 0.0;
    double g = 0.0;
    double b = 0.0;

    if (value < 0.125) {
      b = 0.5 + 4.0 * value; // 0.5 to 1.0
    } else if (value < 0.375) {
      b = 1.0;
      g = 4.0 * (value - 0.125); // 0.0 to 1.0
    } else if (value < 0.625) {
      g = 1.0;
      r = 4.0 * (value - 0.375); // 0.0 to 1.0
      b = 1.0 - 4.0 * (value - 0.375); // 1.0 to 0.0
    } else if (value < 0.875) {
      r = 1.0;
      g = 1.0 - 4.0 * (value - 0.625); // 1.0 to 0.0
    } else {
      r = 1.0 - 4.0 * (value - 0.875) * 0.5; // 1.0 to 0.5
    }

    return Color.fromARGB(
      (value * 120 + 30).toInt().clamp(0, 255), // Dynamic transparency based on weight
      (r * 255).toInt().clamp(0, 255),
      (g * 255).toInt().clamp(0, 255),
      (b * 255).toInt().clamp(0, 255),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (weights.isEmpty) return;

    // Find min and max for normalization
    double minVal = weights.reduce(min);
    double maxVal = weights.reduce(max);
    double range = maxVal - minVal;
    if (range == 0.0) range = 1.0;

    final cellWidth = size.width / 8;
    final cellHeight = size.height / 8;

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final weight = weights[y * 8 + x];
        final normalized = (weight - minVal) / range;

        final rect = Rect.fromLTWH(x * cellWidth, y * cellHeight, cellWidth, cellHeight);
        final paint = Paint()
          ..color = getJetColor(normalized)
          ..style = PaintingStyle.fill;
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant AttentionPainter oldDelegate) {
    return oldDelegate.weights != weights;
  }
}
