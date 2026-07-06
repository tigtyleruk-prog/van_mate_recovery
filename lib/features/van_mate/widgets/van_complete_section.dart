import 'package:flutter/material.dart';

class VanCompleteSection extends StatelessWidget {
  const VanCompleteSection({
    super.key,
    this.completedAt,
    this.photos,
    this.finalNotes,
  });

  final DateTime? completedAt;
  final List<String>? photos;
  final String? finalNotes;

  String get _completionDate {
    if (completedAt != null) {
      final day = completedAt!.day;
      final month = _monthNames[completedAt!.month - 1];
      final year = completedAt!.year;
      return '$day $month $year';
    }
    return '30 Jan 2024';
  }

  static const _completionStatus = 'Completed successfully';

  String get _photoCount {
    if (photos != null && photos!.isNotEmpty) {
      final count = photos!.length;
      return count == 1 ? '1 photo attached' : '$count photos attached';
    }
    return 'No completion photos attached';
  }

  String get _completionNotes {
    final notes = finalNotes?.trim() ?? '';
    return notes.isEmpty ? 'No completion notes' : notes;
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
          summary: '$_completionDate - $_completionStatus',
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
              const SizedBox(height: 6),
              Text(
                'Notes: $_completionNotes',
                style: TextStyle(color: subtitleColor, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _CompleteCard(
          title: 'Completion Photos',
          icon: Icons.photo_library_outlined,
          summary: _photoCount,
          cardColor: cardColor,
          borderColor: borderColor,
          child: Text(
            _photoCount,
            style: TextStyle(color: subtitleColor, height: 1.4),
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
