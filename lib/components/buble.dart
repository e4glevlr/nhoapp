import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/animation.dart';

class BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    // Vẽ vài bong bóng ngẫu nhiên
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.3), 60, paint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.5), 40, paint);
    canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.8), 80, paint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.2), 30, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}