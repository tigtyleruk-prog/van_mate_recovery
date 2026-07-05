import 'package:flutter/material.dart';

class TradeMaterialsSection extends StatelessWidget {
  const TradeMaterialsSection({
    super.key,
    this.materialsList,
    this.quantities,
    this.unitPrices,
    this.materialCosts,
    this.materialsTotal,
    this.labourEstimate,
    this.notes,
  });

  // TODO: Replace with real material list when material model exists
  final String? materialsList;
  // TODO: Replace with real quantities when material model exists
  final String? quantities;
  // TODO: Replace with real unit prices when material model exists
  final String? unitPrices;
  // TODO: Replace with real material cost breakdown when available
  final String? materialCosts;
  // TODO: Replace with real materials total when available
  final String? materialsTotal;
  // TODO: Replace with real labour estimate when available
  final String? labourEstimate;
  // TODO: Replace with real notes when available
  final String? notes;

  static const _defaultMaterialsList =
      'Fence panels x8\nConcrete posts x8\nGravel boards x8';
  static const _defaultLabourEstimate = '2 days';
  static const _defaultMaterialCosts = '£550';
  static const _defaultMaterialsTotal = '£1,290';

  String get _displayMaterialsList => materialsList?.trim().isNotEmpty == true
      ? materialsList!.trim()
      : _defaultMaterialsList;
  String get _displayLabourEstimate => labourEstimate?.trim().isNotEmpty == true
      ? labourEstimate!.trim()
      : _defaultLabourEstimate;
  String get _displayMaterialCosts => materialCosts?.trim().isNotEmpty == true
      ? materialCosts!.trim()
      : _defaultMaterialCosts;
  String get _displayMaterialsTotal => materialsTotal?.trim().isNotEmpty == true
      ? materialsTotal!.trim()
      : _defaultMaterialsTotal;

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
        _MaterialsCard(
          title: 'Materials List',
          icon: Icons.inventory_2_outlined,
          summary: _displayMaterialsList.replaceAll('\n', ', '),
          cardColor: cardColor,
          borderColor: borderColor,
          child: Text(
            _displayMaterialsList,
            style: TextStyle(color: subtitleColor, height: 1.5),
          ),
        ),
        const SizedBox(height: 10),
        _MaterialsCard(
          title: 'Labour Estimate',
          icon: Icons.engineering_outlined,
          summary: _displayLabourEstimate,
          cardColor: cardColor,
          borderColor: borderColor,
          child: Text(
            _displayLabourEstimate,
            style: TextStyle(color: subtitleColor, height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        _MaterialsCard(
          title: 'Material Costs',
          icon: Icons.payments_outlined,
          summary: _displayMaterialCosts,
          cardColor: cardColor,
          borderColor: borderColor,
          child: Text(
            _displayMaterialCosts,
            style: TextStyle(color: subtitleColor, height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        _MaterialsCard(
          title: 'Materials Total',
          icon: Icons.calculate_outlined,
          summary: _displayMaterialsTotal,
          cardColor: cardColor,
          borderColor: borderColor,
          child: Text(
            _displayMaterialsTotal,
            style: TextStyle(color: subtitleColor, height: 1.4),
          ),
        ),
        if (notes != null && notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _MaterialsCard(
            title: 'Notes',
            icon: Icons.notes_outlined,
            summary: 'Has notes',
            cardColor: cardColor,
            borderColor: borderColor,
            child: Text(
              notes!.trim(),
              style: TextStyle(color: subtitleColor, height: 1.4),
            ),
          ),
        ],
      ],
    );
  }
}

class _MaterialsCard extends StatelessWidget {
  const _MaterialsCard({
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