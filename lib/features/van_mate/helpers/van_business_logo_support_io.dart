import 'dart:io';

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
        return _buildLocalLogoPreview(path, fit: fit);
      },
    );
  }

  return _buildLocalLogoPreview(path, fit: fit);
}

Widget _buildLocalLogoPreview(String? path, {BoxFit fit = BoxFit.cover}) {
  final value = path?.trim();
  if (value == null || value.isEmpty) {
    return const Center(
      child: Icon(Icons.image_outlined, color: Colors.white, size: 28),
    );
  }

  String imageKey = value;
  try {
    final modifiedAt = File(value).lastModifiedSync().millisecondsSinceEpoch;
    imageKey = '$value:$modifiedAt';
  } catch (_) {
    imageKey = value;
  }

  return Image.file(
    File(value),
    key: ValueKey<String>(imageKey),
    fit: fit,
    errorBuilder: (context, error, stackTrace) {
      return const Center(
        child: Icon(Icons.image_outlined, color: Colors.white, size: 28),
      );
    },
  );
}
