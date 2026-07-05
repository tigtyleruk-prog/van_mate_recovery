import 'package:flutter/material.dart';

class TradeQuoteSection extends StatelessWidget {
  const TradeQuoteSection({super.key});

  static const _quoteSummary =
      'Full kitchen renovation including removal of existing units, plumbing, electrical work, and installation of new units.';
  static const _quoteTotal = '£8,450';
  static const _quoteStatus = 'Awaiting customer response';

  static const _labourBreakdown = '''
Carpentry & installation: 3 days @ £320/day
Plumbing: 1 day @ £280/day
Electrical: 1 day @ £260/day
Tiling: 2 days @ £240/day
Decorating: 1 day @ £220/day
Waste removal: Half day @ £180''';

  static const _materialsBreakdown = '''
Kitchen units: £2,400
Worktops: £850
Sink & taps: £420
Appliances: £1,800
Tiles & grout: £380
Paint & finishes: £220
Fixings & sundries: £180''';

  static const _quoteNotes = '''
• All work to comply with current building regulations
• Customer to supply appliances if not using our recommended package
• 12-month workmanship guarantee included
• Payment terms: 30% deposit, 40% at mid-point, 30% on completion
• Estimated start date: within 2 weeks of quote acceptance''';

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
                  Text(
                    _quoteTotal,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
          cardColor: cardColor,
          borderColor: borderColor,
        ),
        const SizedBox(height: 10),
        _QuoteCard(
          title: 'Labour Breakdown',
          icon: Icons.engineering_outlined,
          summary: '5.5 days estimated',
          child: Text(
            _labourBreakdown,
            style: TextStyle(color: subtitleColor, height: 1.5),
          ),
          cardColor: cardColor,
          borderColor: borderColor,
        ),
        const SizedBox(height: 10),
        _QuoteCard(
          title: 'Materials Breakdown',
          icon: Icons.inventory_2_outlined,
          summary: '£6,250 materials',
          child: Text(
            _materialsBreakdown,
            style: TextStyle(color: subtitleColor, height: 1.5),
          ),
          cardColor: cardColor,
          borderColor: borderColor,
        ),
        const SizedBox(height: 10),
        _QuoteCard(
          title: 'Quote Notes',
          icon: Icons.notes_outlined,
          summary: '4 notes',
          child: Text(
            _quoteNotes,
            style: TextStyle(color: subtitleColor, height: 1.5),
          ),
          cardColor: cardColor,
          borderColor: borderColor,
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