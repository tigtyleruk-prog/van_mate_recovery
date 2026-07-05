import 'package:flutter/material.dart';

class SurveySection extends StatelessWidget {
  const SurveySection({super.key});

  static const _photoCount = 12;
  static const _measurements = 'Width: 3.2m, Height: 2.4m, Depth: 0.8m';
  static const _accessNotes =
      'Side gate access. Narrow path along left side of house.';
  static const _surveyNotes =
      'Existing fence removed. New fence and gate installed. Ground level even.';

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
        _SurveyCard(
          title: 'Photos',
          icon: Icons.photo_camera_outlined,
          summary: '$_photoCount photos attached',
          cardColor: cardColor,
          borderColor: borderColor,
          child: Text(
            '$_photoCount photos attached',
            style: TextStyle(color: subtitleColor, height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        _SurveyCard(
          title: 'Measurements',
          icon: Icons.straighten_outlined,
          summary: _measurements,
          cardColor: cardColor,
          borderColor: borderColor,
          child: Text(
            _measurements,
            style: TextStyle(color: subtitleColor, height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        _SurveyCard(
          title: 'Access Notes',
          icon: Icons.directions_outlined,
          summary: _accessNotes,
          cardColor: cardColor,
          borderColor: borderColor,
          child: Text(
            _accessNotes,
            style: TextStyle(color: subtitleColor, height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        _SurveyCard(
          title: 'Survey Notes',
          icon: Icons.notes_outlined,
          summary: _surveyNotes,
          cardColor: cardColor,
          borderColor: borderColor,
          child: Text(
            _surveyNotes,
            style: TextStyle(color: subtitleColor, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _SurveyCard extends StatelessWidget {
  const _SurveyCard({
    required this.title,
    required this.icon,
    required this.summary,
    required this.cardColor,
    required this.borderColor,
    required this.child,
  });

  final String title;
  final IconData icon;
  final String summary;
  final Color cardColor;
  final Color borderColor;
  final Widget child;

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