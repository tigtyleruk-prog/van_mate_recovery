import 'package:flutter/material.dart';

class VanMateBottomNavItem {
  final String label;
  final IconData? icon;

  const VanMateBottomNavItem({required this.label, this.icon});
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
                right: index == items.length - 1 ? 0 : 4,
              ),
              child: _VanMateBottomNavButton(
                label: items[index].label,
                icon: items[index].icon,
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
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _VanMateBottomNavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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
          child: icon == null
              ? Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: Colors.white),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
