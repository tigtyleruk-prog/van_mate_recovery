import 'package:flutter/material.dart';

class VanJobProgressStrip extends StatelessWidget {
  const VanJobProgressStrip({super.key, required this.currentStage});

  static const _stages = <String>['Request', 'Quote', 'Schedule', 'Invoice'];

  final int currentStage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = const Color(0xFF4A7DFF);
    final completeColor = const Color(0xFF58D0A4);
    final pendingColor = isDark
        ? Colors.white.withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: 0.28);
    final pendingLabelColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.55);
    final lineColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.14);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: List.generate(_stages.length * 2 - 1, (index) {
          if (index.isEven) {
            final stepIndex = index ~/ 2;
            final stageNumber = stepIndex + 1;
            final isComplete = stageNumber < currentStage;
            final isCurrent = stageNumber == currentStage;
            final isPending = stageNumber > currentStage;

            Color circleColor;
            Color numberColor;
            if (isComplete) {
              circleColor = completeColor;
              numberColor = Colors.white;
            } else if (isCurrent) {
              circleColor = activeColor;
              numberColor = Colors.white;
            } else {
              circleColor = Colors.transparent;
              numberColor = pendingColor;
            }

            return SizedBox(
              width: 72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: circleColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isPending ? pendingColor : circleColor,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$stageNumber',
                        style: TextStyle(
                          color: numberColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _stages[stepIndex],
                    style: TextStyle(
                      color: isPending ? pendingLabelColor : Colors.white,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            );
          }

          final lineIndex = (index - 1) ~/ 2;
          final lineStage = lineIndex + 1;
          final isLineComplete = lineStage < currentStage;

          return SizedBox(
            width: 28,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Container(
                height: 2,
                color: isLineComplete ? completeColor : lineColor,
              ),
            ),
          );
        }),
      ),
    );
  }
}
