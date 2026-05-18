import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static Widget backgroundImage() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1522), Color(0xFF070B12), Color(0xFF05070B)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.6, -0.9),
              radius: 1.25,
              colors: [
                Color(0xFF284A86),
                Color(0xFF1A2740),
                Colors.transparent,
              ],
              stops: [0.0, 0.38, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
