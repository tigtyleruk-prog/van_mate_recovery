import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../services/van_premium_service.dart';

class VanPremiumPage extends StatefulWidget {
  const VanPremiumPage({super.key});

  @override
  State<VanPremiumPage> createState() => _VanPremiumPageState();
}

class _VanPremiumPageState extends State<VanPremiumPage> {
  @override
  void initState() {
    super.initState();
    unawaited(VanMatePremiumService.instance.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.28)),
          SafeArea(
            child: AnimatedBuilder(
              animation: VanMatePremiumService.instance,
              builder: (context, _) {
                final premiumService = VanMatePremiumService.instance;
                final premiumEnabled = premiumService.isPremium;
                final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;

                return ListView(
                  padding: EdgeInsets.fromLTRB(18, 18, 18, bottomPadding),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: const Color(
                              0xFF4A7DFF,
                            ).withValues(alpha: 0.18),
                            border: Border.all(
                              color: const Color(
                                0xFF4A7DFF,
                              ).withValues(alpha: 0.28),
                            ),
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Van Mate Premium',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Smarter route planning, larger saved routes, and convenience tools for delivery drivers.',
                                style: TextStyle(
                                  fontSize: 13.1,
                                  height: 1.38,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.74),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _PremiumPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Premium makes bigger routes easier',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Premium is a convenience upgrade for drivers who want faster setup, fewer splits, and cleaner repeat runs. Manual route building stays free.',
                            style: TextStyle(
                              fontSize: 12.8,
                              height: 1.42,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.76),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: const [
                              _FeatureChip(label: 'Profile-managed'),
                              _FeatureChip(label: 'Test friendly'),
                              _FeatureChip(label: 'No route blocking'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PremiumPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 360;

                              if (compact) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'What Premium unlocks',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _ModePill(
                                      label: premiumEnabled
                                          ? 'Premium active'
                                          : 'Premium off',
                                      accent: premiumEnabled
                                          ? const Color(0xFF58D0A4)
                                          : const Color(0xFF7EA2FF),
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'What Premium unlocks',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _ModePill(
                                    label: premiumEnabled
                                        ? 'Premium active'
                                        : 'Premium off',
                                    accent: premiumEnabled
                                        ? const Color(0xFF58D0A4)
                                        : const Color(0xFF7EA2FF),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Current saved-route cap: ${premiumService.maxDropsPerRoute} drops.',
                            style: TextStyle(
                              fontSize: 12.1,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _PremiumBenefit(
                            icon: Icons.alt_route_rounded,
                            title: 'Smart Auto Plan',
                            body:
                                'Order your stops in one tap and skip the manual shuffle.',
                          ),
                          const SizedBox(height: 10),
                          const _PremiumBenefit(
                            icon: Icons.document_scanner_outlined,
                            title: 'Scan Drop OCR',
                            body:
                                'Scan a label, crop address, save fast.',
                          ),
                          const SizedBox(height: 10),
                          const _PremiumBenefit(
                            icon: Icons.route_rounded,
                            title: 'Google road route preview',
                            body:
                                'See a road-following preview with ETA and distance.',
                          ),
                          const SizedBox(height: 10),
                          const _PremiumBenefit(
                            icon: Icons.inventory_2_rounded,
                            title: 'Save routes up to 25 drops',
                            body:
                                'Premium raises the per-route save cap from 10 drops to 25.',
                          ),
                          const SizedBox(height: 10),
                          const _PremiumBenefit(
                            icon: Icons.route_rounded,
                            title: 'Faster setup for bigger days',
                            body:
                                'Reduce route splitting and get bigger rounds ready faster.',
                          ),
                          const SizedBox(height: 10),
                          const _PremiumBenefit(
                            icon: Icons.shuffle_rounded,
                            title: 'Route Templates',
                            body:
                                'Save named regular runs and load them back when the day repeats.',
                          ),
                          const SizedBox(height: 10),
                          const _PremiumBenefit(
                            icon: Icons.star_border_rounded,
                            title: 'Favourites / Quick Access',
                            body: 'Coming soon as the premium toolkit grows.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PremiumPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Billing status',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Billing coming soon. This screen stays test-friendly so we can keep building the premium foundation before subscriptions are switched on.',
                            style: TextStyle(
                              fontSize: 12.8,
                              height: 1.38,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.76),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PremiumPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Built for the road',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Keep the tools that matter free, and use Premium when the route gets larger or more repetitive.',
                            style: TextStyle(
                              fontSize: 12.8,
                              height: 1.42,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.76),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Manage premium status from Profile. Manual route building, saved drops, navigation, and profile sync stay free.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.7,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;

  const _FeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF4A7DFF).withValues(alpha: 0.16),
        border: Border.all(
          color: const Color(0xFF4A7DFF).withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.6,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _PremiumPanel extends StatelessWidget {
  final Widget child;

  const _PremiumPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PremiumBenefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PremiumBenefit({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.3,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.76),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final Color accent;

  const _ModePill({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: accent.withValues(alpha: 0.18),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
