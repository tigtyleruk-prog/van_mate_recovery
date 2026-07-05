import 'package:flutter/material.dart';

String? resolveSavedVanBusinessLogoUrl(String? url) {
  final value = url?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  return null;
}

String? resolveSavedVanBusinessLogoPath(String? path) => null;

Widget buildVanBusinessLogoPreview(
  String? path, {
  String? logoUrl,
  BoxFit fit = BoxFit.cover,
}) {
  final resolvedLogoUrl = resolveSavedVanBusinessLogoUrl(logoUrl);
  if (resolvedLogoUrl != null) {
    return Image.network(
      resolvedLogoUrl,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.image_outlined, color: Colors.white, size: 28),
        );
      },
    );
  }

  return const Center(
    child: Icon(Icons.image_outlined, color: Colors.white, size: 28),
  );
}
