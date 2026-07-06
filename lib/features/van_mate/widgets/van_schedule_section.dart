import 'package:flutter/material.dart';

class VanScheduleSection extends StatelessWidget {
  const VanScheduleSection({super.key, this.showTeamNotes = true});

  final bool showTeamNotes;

  static const _jobDate = '29 Jan 2024';
  static const _startTime = '09:00';
  static const _estimatedDuration = '1 day';
  static const _teamMember = 'Dave';
  static const _notes = '''• Bring post hole digger
• Customer will be at work
• Access via side gate
• Parking available on street''';

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
        _ScheduleCard(
          title: 'Job Date',
          icon: Icons.calendar_today_outlined,
          summary: _jobDate,
          cardColor: cardColor,
          borderColor: borderColor,
          child: Text(
            _jobDate,
            style: TextStyle(color: subtitleColor, height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        _ScheduleCard(
          title: 'Start Time',
          icon: Icons.schedule_outlined,
          summary: _startTime,
          cardColor: cardColor,
          borderColor: borderColor,
          child: Text(
            _startTime,
            style: TextStyle(color: subtitleColor, height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        _ScheduleCard(
          title: 'Estimated Duration',
          icon: Icons.timelapse_outlined,
          summary: _estimatedDuration,
          cardColor: cardColor,
          borderColor: borderColor,
          child: Text(
            _estimatedDuration,
            style: TextStyle(color: subtitleColor, height: 1.4),
          ),
        ),
        if (showTeamNotes) ...[
          const SizedBox(height: 10),
          _ScheduleCard(
            title: 'Team / Notes',
            icon: Icons.people_outline,
            summary: '1 team member, 4 notes',
            cardColor: cardColor,
            borderColor: borderColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Team member: $_teamMember',
                  style: TextStyle(color: subtitleColor, height: 1.5),
                ),
                const SizedBox(height: 10),
                Text(
                  _notes,
                  style: TextStyle(color: subtitleColor, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
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
