import 'package:flutter/material.dart';

class VanMateBottomNavItem {
  final String label;

  const VanMateBottomNavItem({required this.label});
}

class VanMateBottomNav extends StatelessWidget {
  final List<VanMateBottomNavItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  const VanMateBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == items.length - 1 ? 0 : 6,
              ),
              child: _VanMateBottomNavButton(
                label: items[index].label,
                selected: selectedIndex == index,
                onTap: () => onSelected(index),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VanMateBottomNavButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _VanMateBottomNavButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF3F67FF), Color(0xFF6D97FF)],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
