import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/van_premium_service.dart';

Future<void> showVanMateGuideDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return const _VanMateGuideDialog();
    },
  );
}

class _VanMateGuideDialog extends StatelessWidget {
  const _VanMateGuideDialog();

  List<_VanGuideItem> get _items => <_VanGuideItem>[
    const _VanGuideItem(
      title: 'Today',
      body:
          'Today shows the live run. Open the current stop, then use Navigate, Done, or Failed as you work through the day.',
    ),
    const _VanGuideItem(
      title: 'Map',
      body:
          'Map helps you view saved drops, search nearby places, and open the full map when you need more room.',
    ),
    const _VanGuideItem(
      title: 'Places',
      body:
          'Places is your private saved drop library. Save precise pins here, then reuse them in Route or open them in navigation.',
    ),
    const _VanGuideItem(
      title: 'Manage',
      body:
          'Open Manage on a saved drop to request the exact pin, pin your current location, or share entrance info after checking private fields.',
    ),
    _VanGuideItem(
      title: 'Route',
      body:
          'Route is where you build today\'s run. Add drops from Places, set optional start and end anchors, reorder them manually, and save smaller routes free. Free routes support up to ${VanMatePremiumService.freeRouteStopLimit} drops, while Premium raises that to ${VanMatePremiumService.premiumRouteStopLimit} and unlocks Smart Auto Plan.',
    ),
    const _VanGuideItem(
      title: 'Good to know',
      body:
          'Van Mate keeps your drops private to your account. The route planner puts your saved drops into an ordered stop list only. For real turn-by-turn directions, use the Navigate button on the current stop or saved drop, which opens your preferred navigation app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A2942).withValues(alpha: 0.94),
                  const Color(0xFF10192A).withValues(alpha: 0.96),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Van Mate Guide',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Quick driver-focused reminders for planning, saved drops, and live navigation.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.4,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
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
                const SizedBox(height: 16),
                Flexible(
                  child: Scrollbar(
                    thumbVisibility: false,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _VanGuideCard(item: item);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VanGuideCard extends StatelessWidget {
  const _VanGuideCard({required this.item});

  final _VanGuideItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 12.6,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VanGuideItem {
  const _VanGuideItem({required this.title, required this.body});

  final String title;
  final String body;
}
