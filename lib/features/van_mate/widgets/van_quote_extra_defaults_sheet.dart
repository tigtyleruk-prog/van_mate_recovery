import 'package:flutter/material.dart';

import '../models/van_quote_extra_defaults.dart';
import '../widgets/van_form_field_styles.dart';

class VanQuoteExtraDefaultsSheet extends StatefulWidget {
  const VanQuoteExtraDefaultsSheet({super.key, required this.initialDefaults});

  final VanQuoteExtraDefaults initialDefaults;

  @override
  State<VanQuoteExtraDefaultsSheet> createState() =>
      _VanQuoteExtraDefaultsSheetState();
}

class _VanQuoteExtraDefaultsSheetState
    extends State<VanQuoteExtraDefaultsSheet> {
  final Map<String, TextEditingController> _labelControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _priceControllers =
      <String, TextEditingController>{};
  final Map<String, bool> _enabledValues = <String, bool>{};

  @override
  void initState() {
    super.initState();
    for (final extra in widget.initialDefaults.orderedExtras) {
      _labelControllers[extra.key] = TextEditingController(
        text: extra.resolvedLabel,
      );
      _priceControllers[extra.key] = TextEditingController(
        text: extra.defaultPrice == 0
            ? '0'
            : extra.defaultPrice.toStringAsFixed(2),
      );
      _enabledValues[extra.key] = extra.enabled;
    }
  }

  @override
  void dispose() {
    for (final controller in _labelControllers.values) {
      controller.dispose();
    }
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _priceForKey(String key) {
    final value = _priceControllers[key]?.text.trim() ?? '';
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) {
      return 0;
    }
    return double.tryParse(cleaned) ?? 0;
  }

  VanQuoteExtraDefaults _buildDefaults() {
    var defaults = widget.initialDefaults;
    for (final key in kVanQuoteExtraDefaultOrder) {
      final existing = widget.initialDefaults.extraForKey(key);
      final label = _labelControllers[key]?.text.trim() ?? '';
      defaults = defaults.copyWithExtra(
        existing.copyWith(
          label: label.isEmpty
              ? (kVanQuoteExtraDefaultLabels[key] ?? existing.resolvedLabel)
              : label,
          defaultPrice: _priceForKey(key),
          enabled: _enabledValues[key] ?? true,
        ),
      );
    }
    return defaults;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 680),
          decoration: const BoxDecoration(
            color: Color(0xFF101B2A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Saved extras',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Set the quick extra labels and amounts used when building quotes.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                for (final key in kVanQuoteExtraDefaultOrder) ...[
                  _SavedExtraEditorRow(
                    title: kVanQuoteExtraDefaultLabels[key] ?? 'Extra',
                    labelController: _labelControllers[key]!,
                    priceController: _priceControllers[key]!,
                    enabled: _enabledValues[key] ?? true,
                    onEnabledChanged: (value) {
                      _enabledValues[key] = value;
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_buildDefaults()),
                  icon: const Icon(Icons.check),
                  label: const Text('Save extras'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: const Color(0xFF58D0A4),
                    foregroundColor: const Color(0xFF07130F),
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

class _SavedExtraEditorRow extends StatefulWidget {
  const _SavedExtraEditorRow({
    required this.title,
    required this.labelController,
    required this.priceController,
    required this.enabled,
    required this.onEnabledChanged,
  });

  final String title;
  final TextEditingController labelController;
  final TextEditingController priceController;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;

  @override
  State<_SavedExtraEditorRow> createState() => _SavedExtraEditorRowState();
}

class _SavedExtraEditorRowState extends State<_SavedExtraEditorRow> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
  }

  @override
  void didUpdateWidget(_SavedExtraEditorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _enabled = widget.enabled;
    }
  }

  void _handleEnabledChanged(bool value) {
    setState(() {
      _enabled = value;
    });
    widget.onEnabledChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _enabled,
                onChanged: _handleEnabledChanged,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 460;
              final fields = <Widget>[
                TextField(
                  controller: widget.labelController,
                  style: kVanMateFieldTextStyle,
                  decoration: vanMateFieldDecoration(
                    label: 'Label',
                    hintText: widget.title,
                  ),
                ),
                TextField(
                  controller: widget.priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: kVanMateFieldTextStyle,
                  decoration: vanMateFieldDecoration(
                    label: 'Default price',
                    hintText: '0.00',
                    prefixText: '\u00A3',
                  ),
                ),
              ];

              if (stacked) {
                return Column(
                  children: [fields[0], const SizedBox(height: 8), fields[1]],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: fields[0]),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: fields[1]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
