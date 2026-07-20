import 'package:flutter/material.dart';

class VanCalendarCompactActionCard extends StatefulWidget {
  const VanCalendarCompactActionCard({
    super.key,
    required this.cardId,
    required this.actionLabel,
    this.actionIcon,
    required this.customerName,
    required this.accent,
    required this.timeChip,
    required this.statusChip,
    required this.expandedChild,
    required this.onOpen,
  });

  final String cardId;
  final String actionLabel;
  final IconData? actionIcon;
  final String customerName;
  final Color accent;
  final Widget timeChip;
  final Widget statusChip;
  final Widget expandedChild;
  final VoidCallback onOpen;

  @override
  State<VanCalendarCompactActionCard> createState() =>
      _VanCalendarCompactActionCardState();
}

class _VanCalendarCompactActionCardState
    extends State<VanCalendarCompactActionCard> {
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardKey = 'van-calendar-action-${widget.cardId}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onOpen,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Container(
            key: ValueKey<String>(cardKey),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.accent.withValues(alpha: 0.20),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(color: widget.accent.withValues(alpha: 0.30)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: widget.accent,
                    ),
                    child: SizedBox(width: 4, height: _expanded ? 76 : 48),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    if (widget.actionIcon != null) ...[
                                      Icon(
                                        widget.actionIcon,
                                        size: 17,
                                        color: widget.accent,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Expanded(
                                      child: Text(
                                        widget.actionLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: widget.accent,
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: IconButton(
                              key: ValueKey<String>('$cardKey-toggle'),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              tooltip: _expanded
                                  ? 'Collapse details'
                                  : 'Expand details',
                              onPressed: _toggleExpanded,
                              icon: AnimatedRotation(
                                turns: _expanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 180),
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [widget.timeChip, widget.statusChip],
                      ),
                      if (_expanded) ...[
                        const SizedBox(height: 10),
                        Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                        const SizedBox(height: 10),
                        KeyedSubtree(
                          key: ValueKey<String>('$cardKey-expanded'),
                          child: widget.expandedChild,
                        ),
                      ],
                    ],
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
