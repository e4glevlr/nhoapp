import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  const GlassmorphicContainer({Key? key, required this.child}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.compose(outer: ImageFilter.blur(sigmaX: 10, sigmaY: 10), inner: ColorFilter.matrix(<double>[0.3584, 0.6154, 0.0262, 0.0, 0.0, -0.1498, 0.8622, -0.0144, 0.0, 0.0, -0.1498, -0.2866, 1.1164, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0])),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(width: 1.5, color: Colors.white.withOpacity(0.16)),
          ),
          child: child,
        ),
      ),
    );
  }
}