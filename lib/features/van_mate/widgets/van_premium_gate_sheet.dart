import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/van_premium_service.dart';
import '../pages/van_premium_page.dart';

Future<void> showVanMatePremiumGate(
  BuildContext context, {
  String featureName = 'Smart Auto Plan',
  String? headline,
  String? message,
  String ctaLabel = 'Open Premium screen',
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _VanPremiumGateSheet(
        featureName: featureName,
        headline: headline,
        message: message,
        ctaLabel: ctaLabel,
        onOpenPremium: () async {
          Navigator.of(sheetContext).pop();
          await navigator.push(
            MaterialPageRoute<void>(builder: (_) => const VanPremiumPage()),
          );
        },
      );
    },
  );
}

Future<bool> requireVanMatePremium(
  BuildContext context, {
  String featureName = 'Smart Auto Plan',
  String? headline,
  String? message,
  String ctaLabel = 'Open Premium screen',
}) async {
  final premiumService = VanMatePremiumService.instance;
  await premiumService.ensureLoaded();
  if (premiumService.isPremium) {
    return true;
  }

  if (!context.mounted) {
    return false;
  }

  await showVanMatePremiumGate(
    context,
    featureName: featureName,
    headline: headline,
    message: message,
    ctaLabel: ctaLabel,
  );
  return false;
}

class _VanPremiumGateSheet extends StatelessWidget {
  final String featureName;
  final String? headline;
  final String? message;
  final String ctaLabel;
  final Future<void> Function() onOpenPremium;

  const _VanPremiumGateSheet({
    required this.featureName,
    required this.headline,
    required this.message,
    required this.ctaLabel,
    required this.onOpenPremium,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewPadding.bottom + 24;
    final sheetHeight = mediaQuery.size.height * 0.88;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: sheetHeight,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A2942).withValues(alpha: 0.96),
                    const Color(0xFF10192A).withValues(alpha: 0.97),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  headline ?? '$featureName is Premium',
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  message ??
                                      'Manual route building stays free. Premium unlocks Scan Drop OCR, Google road route preview, and smarter planning for drivers who want a quicker first pass.',
                                  style: TextStyle(
                                    fontSize: 12.4,
                                    height: 1.36,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.76),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.white.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _BenefitRow(
                        icon: Icons.alt_route_rounded,
                        title: 'Smarter route planning',
                        body: 'Use Smart Auto Plan to order your stops faster.',
                      ),
                      const SizedBox(height: 6),
                      _BenefitRow(
                        icon: Icons.restart_alt_rounded,
                        title: 'Faster repeat runs',
                        body:
                            'Keep the route flow tight when you run the same area again.',
                      ),
                      const SizedBox(height: 6),
                      _BenefitRow(
                        icon: Icons.workspace_premium_rounded,
                        title: 'Premium convenience tools',
                        body:
                            'Extra tools for delivery drivers, with more to come later.',
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withValues(alpha: 0.06),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Text(
                          'Coming soon: billing will be added later. For now, this screen is test-friendly so we can build and validate the Premium flow.',
                          style: TextStyle(
                            fontSize: 12.2,
                            height: 1.34,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.74),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onOpenPremium,
                          icon: const Icon(Icons.settings_rounded),
                          label: Text(ctaLabel),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Not now'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: const Color(0xFF4A7DFF).withValues(alpha: 0.18),
              border: Border.all(
                color: const Color(0xFF4A7DFF).withValues(alpha: 0.26),
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.8,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.1,
                    height: 1.32,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.76),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
