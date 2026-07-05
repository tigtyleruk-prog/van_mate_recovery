import 'package:flutter/material.dart';

class TradeCompleteSection extends StatelessWidget {
  const TradeCompleteSection({
    super.key,
    this.completedAt,
    this.photos,
    this.finalNotes,
  });

  final DateTime? completedAt;
  final List<String>? photos;
  final String? finalNotes;

  // TODO: Add workItems parameter when work items/tasks model exists
  // TODO: Add signatureStatus parameter when signature model exists
  // TODO: Add rating parameter when customer rating model exists

  String get _completionDate {
    if (completedAt != null) {
      final day = completedAt!.day;
      final month = _monthNames[completedAt!.month - 1];
      final year = completedAt!.year;
      return '$day $month $year';
    }
    return '30 Jan 2024'; // fallback placeholder
  }

  static const _completionStatus = 'Completed successfully';
  static const _beforePhotos = 'Before photos';
  static const _afterPhotos = 'After photos';
  String get _photoCount {
    if (photos != null && photos!.isNotEmpty) {
      final count = photos!.length;
      return count == 1 ? '1 photo attached' : '$count photos attached';
    }
    return '8 photos attached'; // fallback placeholder
  }
  // TODO: Replace with real work items when tasks model exists
  static const _workItems = '''• Fence panels installed
• Gate fitted
• Old fence removed
• Site cleaned and waste removed''';
  // TODO: Connect to signature model when available
  static const _signatureStatus = 'Customer signature received';
  // TODO: Connect to rating model when available
  static const _satisfaction = '★★★★★';
  String get _finalNotes {
    if (finalNotes != null && finalNotes!.trim().isNotEmpty) {
      return '"${finalNotes!.trim()}"';
    }
    return '"No completion notes"'; // fallback placeholder
  }

  static const List<String> _monthNames = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

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
        _CompleteCard(
          title: 'Job Completion',
          icon: Icons.check_circle_outlined,
          summary: '$_completionDate • $_completionStatus',
          cardColor: cardColor,
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completed: $_completionDate',
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                'Status: $_completionStatus',
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _CompleteCard(
          title: 'Completion Photos',
          icon: Icons.photo_library_outlined,
          summary: '$_beforePhotos, $_afterPhotos • $_photoCount',
          cardColor: cardColor,
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _beforePhotos,
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                _afterPhotos,
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                _photoCount,
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _CompleteCard(
          title: 'Work Completed',
          icon: Icons.build_outlined,
          summary: '4 items completed',
          cardColor: cardColor,
          borderColor: borderColor,
          child: Text(
            _workItems,
            style: TextStyle(color: subtitleColor, height: 1.5),
          ),
        ),
        const SizedBox(height: 10),
        _CompleteCard(
          title: 'Customer Sign-off',
          icon: Icons.how_to_reg_outlined,
          summary: '$_signatureStatus • $_satisfaction',
          cardColor: cardColor,
          borderColor: borderColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _signatureStatus,
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                'Customer satisfaction: $_satisfaction',
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 10),
              Text(
                'Final notes:',
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 4),
              Text(
                _finalNotes,
                style: TextStyle(color: subtitleColor, height: 1.4, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompleteCard extends StatelessWidget {
  const _CompleteCard({
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