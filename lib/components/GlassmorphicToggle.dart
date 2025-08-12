import 'dart:ui';
import 'package:flutter/material.dart';

class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final bool isPerformanceMode; // Chế độ hiệu năng cao
  final double borderRadius;
  final double borderWidth;
  final double borderOpacity;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.blurSigma = 5.0, // Giá trị sigma mặc định đã giảm
    this.isPerformanceMode = true, // Mặc định tắt
    this.borderRadius = 16.0,
    this.borderOpacity = 0.16,
    this.borderWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    // Nếu ở chế độ hiệu năng, trả về một container đơn giản
    if (isPerformanceMode) {
      return Container(

        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12), // Tăng độ mờ để dễ nhìn hơn
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
                offset: const Offset(0, 15),
                blurRadius: 10,
                color: const Color(0xFF1731B6).withOpacity(0.20)
            ),
          ],
        ),
        child: child,
      );
    }

    // Nếu không, trả về phiên bản đầy đủ nhưng với giá trị sigma thấp hơn
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma), // Dùng giá trị sigma có thể tùy chỉnh
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(width: borderWidth, color: Colors.white.withOpacity(borderOpacity)),
            // Có thể bỏ boxShadow ở đây để tăng hiệu năng hơn nữa
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 15),
                blurRadius: 15,
                color: const Color(0xFF1731B6).withOpacity(0.35)
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}