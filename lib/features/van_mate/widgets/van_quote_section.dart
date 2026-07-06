import 'package:flutter/material.dart';

class VanQuoteSection extends StatelessWidget {
  const VanQuoteSection({super.key});

  static const _quoteSummary =
      'Courier/removals job covering pickup, loading, transport, unloading, and agreed access notes.';
  static const _quoteTotal = 'GBP 145';
  static const _quoteStatus = 'Awaiting customer response';

  static const _quoteNotes = '''
- Price covers the agreed pickup and drop-off route
- Customer to confirm access, parking, and any stairs or lift details
- Quote excludes extra waiting time or additional stops unless agreed
- Payment instructions are sent separately with the invoice''';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF142031) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.black.withValues(alpha: 0.72);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuoteCard(
          title: 'Quote Summary',
          icon: Icons.receipt_long_outlined,
          summary: _quoteStatus,
          cardColor: cardColor,
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _quoteSummary,
                style: TextStyle(color: subtitleColor, height: 1.5),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Quote',
                    style: TextStyle(
                      color: subtitleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const Text(
                    _quoteTotal,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _QuoteCard(
          title: 'Quote Notes',
          icon: Icons.notes_outlined,
          summary: '4 notes',
          cardColor: cardColor,
          borderColor: borderColor,
          child: Text(
            _quoteNotes,
            style: TextStyle(color: subtitleColor, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.title,
    required this.icon,
    required this.summary,
    required this.child,
    required this.cardColor,
    required this.borderColor,
  });

  final String title;
  final IconData icon;
  final String summary;
  final Widget child;
  final Color cardColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          colorScheme: ColorScheme.dark(
            surface: cardColor,
            onSurface: Colors.white,
          ),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Icon(icon, color: Colors.white, size: 20),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            summary,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [child],
        ),
      ),
    );
  }
}
