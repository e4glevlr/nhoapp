import 'dart:ui';

import 'package:flutter/material.dart';



class GlassmorphicContainer extends StatelessWidget {

  final Widget child;

  final EdgeInsetsGeometry? padding;

  final EdgeInsetsGeometry? margin;

  final double borderRadius;

  final double blur;

  final double opacity;



  const GlassmorphicContainer({

    Key? key,

    required this.child,

    this.padding,

    this.margin,

    this.borderRadius = 20.0,

    this.blur = 20.0,

    this.opacity = 0.15,

  }) : super(key: key);



  @override

  Widget build(BuildContext context) {

    return ClipRRect(

      borderRadius: BorderRadius.circular(borderRadius),

      child: BackdropFilter(

        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),

        child: Container(

          margin: margin,

          padding: padding,

          decoration: BoxDecoration(

            color: Colors.white.withOpacity(opacity), // Trong suốt hơn

            borderRadius: BorderRadius.circular(borderRadius),

            border: Border.all(

              width: 1.2,

              color: Colors.white.withOpacity(0.3), // Viền sáng hơn

            ),

            boxShadow: [

              BoxShadow(

                color: Colors.black.withOpacity(0.08), // Bóng nhẹ

                blurRadius: 20,

                offset: const Offset(0, 4),

              )

            ],

          ),

          child: child,

        ),

      ),

    );

  }

}