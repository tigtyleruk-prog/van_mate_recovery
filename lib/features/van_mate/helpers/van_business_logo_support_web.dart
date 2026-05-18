import 'package:flutter/material.dart';

String? resolveSavedVanBusinessLogoPath(String? path) => null;

Widget buildVanBusinessLogoPreview(String? path, {BoxFit fit = BoxFit.cover}) {
  return const Center(
    child: Icon(Icons.image_outlined, color: Colors.white, size: 28),
  );
}
