import 'package:flutter/material.dart';

enum VanStatusTone { positive, primary, warning, danger, neutral }

const Color kVanStatusPositiveColor = Color(0xFF58D0A4);
const Color kVanStatusPrimaryColor = Color(0xFF4A7DFF);
const Color kVanStatusWarningColor = Color(0xFFFFC38C);
const Color kVanStatusDangerColor = Color(0xFFD24C4C);
const Color kVanStatusNeutralColor = Color(0xFF9AA3B2);

Color vanStatusToneColor(VanStatusTone tone) {
  switch (tone) {
    case VanStatusTone.positive:
      return kVanStatusPositiveColor;
    case VanStatusTone.primary:
      return kVanStatusPrimaryColor;
    case VanStatusTone.warning:
      return kVanStatusWarningColor;
    case VanStatusTone.danger:
      return kVanStatusDangerColor;
    case VanStatusTone.neutral:
      return kVanStatusNeutralColor;
  }
}
