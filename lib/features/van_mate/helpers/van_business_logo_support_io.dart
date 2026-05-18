import 'dart:io';

import 'package:flutter/material.dart';

String? resolveSavedVanBusinessLogoPath(String? path) {
  final value = path?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  try {
    return File(value).existsSync() ? value : null;
  } catch (_) {
    return null;
  }
}

Widget buildVanBusinessLogoPreview(String? path, {BoxFit fit = BoxFit.cover}) {
  final value = path?.trim();
  if (value == null || value.isEmpty) {
    return const Center(
      child: Icon(Icons.image_outlined, color: Colors.white, size: 28),
    );
  }

  return Image.file(
    File(value),
    fit: fit,
    errorBuilder: (context, error, stackTrace) {
      return const Center(
        child: Icon(Icons.image_outlined, color: Colors.white, size: 28),
      );
    },
  );
}
