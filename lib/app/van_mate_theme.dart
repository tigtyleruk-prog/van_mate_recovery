import 'package:flutter/material.dart';

class VanMateTheme {
  const VanMateTheme._();

  static ThemeData light() {
    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF4A7DFF),
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF5F8FF),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF4A7DFF),
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0E1727),
    );
  }
}
