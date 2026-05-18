import 'dart:async';

import 'package:flutter/material.dart';

class VanHomePage extends StatelessWidget {
  final bool isLoading;
  final String? loadError;
  final Future<void> Function() onRetry;

  const VanHomePage({
    super.key,
    required this.isLoading,
    required this.loadError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              key: const ValueKey('home_tab'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroCard(isLoading: isLoading),
                if (loadError != null) ...[
                  const SizedBox(height: 12),
                  _ErrorCard(message: loadError!, onRetry: onRetry),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool isLoading;

  const _HeroCard({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.11),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 560;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroCopy(theme: theme, isLoading: isLoading),
              const SizedBox(height: 6),
              if (narrow) ...[
                const _VanHeroImage(compact: true),
              ] else ...[
                const _VanHeroImage(compact: false),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final ThemeData theme;
  final bool isLoading;

  const _HeroCopy({required this.theme, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Van Mate',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Built for delivery drivers.',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isLoading
              ? 'Loading your driver dashboard.'
              : 'Routes, stops, and saved drops in one clean view.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _VanHeroImage extends StatelessWidget {
  final bool compact;

  const _VanHeroImage({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 216 : 196,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A2740).withValues(alpha: 0.98),
            const Color(0xFF070B12).withValues(alpha: 0.99),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A7DFF).withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: compact ? -18 : -22,
            top: compact ? -18 : -24,
            child: Container(
              width: compact ? 136 : 120,
              height: compact ? 136 : 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6A8FFF).withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: compact ? 16 : 18,
            right: compact ? 16 : 18,
            top: compact ? 34 : 30,
            bottom: compact ? 10 : 12,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.95,
                    colors: [
                      const Color(0xFF6887C0).withValues(alpha: 0.16),
                      const Color(0xFF1B2432).withValues(alpha: 0.00),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            top: compact ? 34 : 30,
            left: compact ? 12 : 10,
            right: compact ? 12 : 10,
            bottom: compact ? 5 : 7,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: compact ? 0.89 : 0.87,
                child: Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: compact ? 16 : 24,
                      right: compact ? 16 : 24,
                      bottom: compact ? 3 : 5,
                      child: Container(
                        height: compact ? 13 : 15,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF05080D,
                              ).withValues(alpha: 0.66),
                              blurRadius: compact ? 16 : 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          gradient: const RadialGradient(
                            colors: [
                              Color(0xFF354D77),
                              Color(0xFF101826),
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.68, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Image.asset(
                      'assets/images/van_mate_van_home.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.error.withValues(alpha: 0.12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sync issue',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              unawaited(onRetry());
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
