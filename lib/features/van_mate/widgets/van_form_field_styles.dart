import 'package:flutter/material.dart';

const Color kVanMateFieldTextColor = Colors.white;
const Color kVanMateFieldLabelColor = Color.fromRGBO(255, 255, 255, 0.68);
const Color kVanMateFieldHintColor = Color.fromRGBO(255, 255, 255, 0.50);
const Color kVanMateFieldIconColor = Color.fromRGBO(255, 255, 255, 0.56);
const Color kVanMateFieldFillColor = Color.fromRGBO(0, 0, 0, 0.14);
const Color kVanMateFieldBorderColor = Color.fromRGBO(255, 255, 255, 0.12);
const Color kVanMateFieldFocusColor = Color(0xFF4A7DFF);

const TextStyle kVanMateFieldTextStyle = TextStyle(
  color: kVanMateFieldTextColor,
  fontWeight: FontWeight.w700,
);

TextStyle kVanMateFieldLabelStyle([double opacity = 0.68]) {
  return TextStyle(
    color: Colors.white.withValues(alpha: opacity),
    fontWeight: FontWeight.w700,
  );
}

TextStyle kVanMateFieldHintStyle([double opacity = 0.50]) {
  return TextStyle(color: Colors.white.withValues(alpha: opacity));
}

InputDecoration vanMateFieldDecoration({
  required String label,
  String? hintText,
  Widget? prefixIcon,
  String? prefixText,
  String? suffixText,
  double labelOpacity = 0.68,
  double hintOpacity = 0.50,
  Color fillColor = kVanMateFieldFillColor,
  EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 14,
  ),
  double focusedBorderWidth = 1.3,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    prefixIcon: prefixIcon == null
        ? null
        : IconTheme(
            data: const IconThemeData(color: kVanMateFieldIconColor),
            child: prefixIcon,
          ),
    prefixText: prefixText,
    suffixText: suffixText,
    filled: true,
    fillColor: fillColor,
    labelStyle: kVanMateFieldLabelStyle(labelOpacity),
    hintStyle: kVanMateFieldHintStyle(hintOpacity),
    contentPadding: contentPadding,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: kVanMateFieldBorderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: kVanMateFieldFocusColor,
        width: focusedBorderWidth,
      ),
    ),
  );
}
