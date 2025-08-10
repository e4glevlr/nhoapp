import 'package:flutter/material.dart';

// lib/helpers/navigation_helper.dart

void navigateToPageWithFade(BuildContext context, Widget page) {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 800),

      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    ),
  );
}