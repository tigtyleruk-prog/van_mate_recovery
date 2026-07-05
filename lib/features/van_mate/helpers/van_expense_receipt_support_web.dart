import 'package:flutter/material.dart';

String? resolveSavedVanExpenseReceiptPath(String? path) => null;

Widget buildVanExpenseReceiptPreview(
  String? path, {
  BoxFit fit = BoxFit.cover,
}) {
  return const Center(
    child: Icon(Icons.receipt_long_outlined, color: Colors.white, size: 28),
  );
}
