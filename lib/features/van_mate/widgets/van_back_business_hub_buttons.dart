import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/business_hub_page.dart';

class VanBackBusinessHubButtons extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onBusinessHub;
  final double gap;
  final double buttonSize;

  const VanBackBusinessHubButtons({
    super.key,
    required this.onBack,
    this.onBusinessHub,
    this.gap = 8,
    this.buttonSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderGlassIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
          size: buttonSize,
        ),
        SizedBox(width: gap),
        _HeaderGlassIconButton(
          icon: Icons.business_center_outlined,
          onTap:
              onBusinessHub ??
              () {
                unawaited(openVanBusinessHubPage(context));
              },
          size: buttonSize,
        ),
      ],
    );
  }
}

class _HeaderGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _HeaderGlassIconButton({
    required this.icon,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, size: 19, color: Colors.white),
        ),
      ),
    );
  }
}
