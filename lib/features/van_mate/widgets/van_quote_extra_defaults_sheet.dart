import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/van_quote_extra_defaults.dart';
import '../widgets/van_form_field_styles.dart';

class VanQuoteExtraDefaultsSheet extends StatefulWidget {
  const VanQuoteExtraDefaultsSheet({
    super.key,
    required this.initialDefaults,
    this.title = 'Saved extras',
    this.description =
        'Set the quick extra labels and amounts used when building quotes.',
    this.saveLabel = 'Save extras',
    this.resetDefaults,
  });

  final VanQuoteExtraDefaults initialDefaults;
  final String title;
  final String description;
  final String saveLabel;
  final VanQuoteExtraDefaults? resetDefaults;

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
  final Map<String, FocusNode> _labelFocusNodes = <String, FocusNode>{};
  final Map<String, FocusNode> _priceFocusNodes = <String, FocusNode>{};
  final Map<String, bool> _enabledValues = <String, bool>{};
  final List<_EditableCustomExtra> _customRows = <_EditableCustomExtra>[];
  final List<String> _extraOrder = <String>[];
  final Set<String> _deletedBuiltInKeys = <String>{};
  int _nextCustomIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadEditableDefaults(widget.initialDefaults);
  }

  void _loadEditableDefaults(VanQuoteExtraDefaults defaults) {
    for (final controller in _labelControllers.values) {
      controller.dispose();
    }
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _labelFocusNodes.values) {
      focusNode.dispose();
    }
    for (final focusNode in _priceFocusNodes.values) {
      focusNode.dispose();
    }
    for (final row in _customRows) {
      row.dispose();
    }
    _labelControllers.clear();
    _priceControllers.clear();
    _labelFocusNodes.clear();
    _priceFocusNodes.clear();
    _enabledValues.clear();
    _customRows.clear();
    _extraOrder.clear();
    _deletedBuiltInKeys.clear();
    _deletedBuiltInKeys.addAll(defaults.deletedBuiltInKeys);
    for (final extra in defaults.orderedExtras) {
      _extraOrder.add(extra.key);
      if (isVanQuoteBuiltInExtraKey(extra.key)) {
        _ensureBuiltInControllers(extra.key, extra: extra);
      } else {
        _customRows.add(_EditableCustomExtra.fromExtra(extra));
      }
    }
    _nextCustomIndex = defaults.customExtras.length;
  }

  @override
  void dispose() {
    for (final controller in _labelControllers.values) {
      controller.dispose();
    }
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _labelFocusNodes.values) {
      focusNode.dispose();
    }
    for (final focusNode in _priceFocusNodes.values) {
      focusNode.dispose();
    }
    for (final row in _customRows) {
      row.dispose();
    }
    super.dispose();
  }

  double _priceForKey(String key) {
    return _priceForController(_priceControllers[key]);
  }

  double _priceForController(TextEditingController? controller) {
    final value = controller?.text.trim() ?? '';
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) {
      return 0;
    }
    return double.tryParse(cleaned) ?? 0;
  }

  void _ensureBuiltInControllers(String key, {VanQuoteExtraDefault? extra}) {
    final defaults = extra ?? widget.initialDefaults.extraForKey(key);
    _labelControllers.putIfAbsent(
      key,
      () => TextEditingController(text: defaults.resolvedLabel),
    );
    _priceControllers.putIfAbsent(
      key,
      () => TextEditingController(
        text: defaults.defaultPrice == 0
            ? '0'
            : defaults.defaultPrice.toStringAsFixed(2),
      ),
    );
    _enabledValues.putIfAbsent(key, () => defaults.enabled);
    _labelFocusNodes.putIfAbsent(
      key,
      () => FocusNode(debugLabel: 'quote-extra-$key-label'),
    );
    _priceFocusNodes.putIfAbsent(
      key,
      () => FocusNode(debugLabel: 'quote-extra-$key-price'),
    );
  }

  _EditableCustomExtra? _customRowForKey(String key) {
    for (final row in _customRows) {
      if (row.key == key) {
        return row;
      }
    }
    return null;
  }

  List<VanQuoteExtraDefault> _orderedCustomExtras() {
    final customExtras = <VanQuoteExtraDefault>[];
    for (final key in _extraOrder) {
      if (isVanQuoteBuiltInExtraKey(key)) {
        continue;
      }
      final row = _customRowForKey(key);
      if (row == null) {
        continue;
      }
      final label = row.labelController.text.trim();
      if (label.isEmpty) {
        continue;
      }
      customExtras.add(
        VanQuoteExtraDefault.custom(
          key: row.key,
          label: label,
          defaultPrice: _priceForController(row.priceController),
          enabled: row.enabled,
        ),
      );
    }
    return customExtras;
  }

  VanQuoteExtraDefaults _buildDefaults() {
    var defaults = VanQuoteExtraDefaults.empty();
    for (final key in _extraOrder.where(isVanQuoteBuiltInExtraKey)) {
      _ensureBuiltInControllers(key);
      final existing = VanQuoteExtraDefault.fallback(key);
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
    defaults = defaults.copyWithCustomExtras(_orderedCustomExtras());
    return defaults.copyWithOrder(_extraOrder);
  }

  void _addCustomExtra() {
    setState(() {
      final row = _EditableCustomExtra.blank(
        key: buildVanQuoteCustomExtraKey(label: '', index: _nextCustomIndex++),
      );
      _customRows.add(row);
      _extraOrder.add(row.key);
    });
  }

  void _deleteCustomExtra(_EditableCustomExtra row) {
    setState(() {
      _customRows.remove(row);
      _extraOrder.remove(row.key);
    });
    row.dispose();
  }

  void _deleteBuiltInExtra(String key) {
    setState(() {
      _deletedBuiltInKeys.add(key);
      _extraOrder.remove(key);
    });
  }

  void _resetDefaults() {
    setState(() {
      final serviceDefaults = widget.resetDefaults;
      if (serviceDefaults != null) {
        _loadEditableDefaults(_buildDefaults().resetToStarter(serviceDefaults));
        return;
      }
      _deletedBuiltInKeys.clear();
      for (final key in kVanQuoteExtraDefaultOrder) {
        final fallback = VanQuoteExtraDefault.fallback(key);
        _ensureBuiltInControllers(key, extra: fallback);
        _labelControllers[key]!.text = fallback.resolvedLabel;
        _priceControllers[key]!.text = fallback.defaultPrice == 0
            ? '0'
            : fallback.defaultPrice.toStringAsFixed(2);
        _enabledValues[key] = fallback.enabled;
      }
      final customOrder = <String>[
        for (final key in _extraOrder)
          if (!isVanQuoteBuiltInExtraKey(key) && _customRowForKey(key) != null)
            key,
      ];
      _extraOrder
        ..clear()
        ..addAll(kVanQuoteExtraDefaultOrder)
        ..addAll(customOrder);
    });
  }

  void _reorderExtra(int oldIndex, int newIndex) {
    setState(() {
      final item = _extraOrder.removeAt(oldIndex);
      _extraOrder.insert(newIndex, item);
    });
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
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            buildDefaultDragHandles: false,
            itemCount: _extraOrder.length,
            onReorderItem: _reorderExtra,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
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
                  widget.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(child: _SectionLabel(text: 'Active extras')),
                    TextButton.icon(
                      onPressed: _resetDefaults,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset defaults'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _addCustomExtra,
                    icon: const Icon(Icons.add),
                    label: const Text('Add custom extra'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF58D0A4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_extraOrder.isEmpty) ...<Widget>[
                  Text(
                    'No active extras saved yet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
            footer: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_buildDefaults()),
              icon: const Icon(Icons.check),
              label: Text(widget.saveLabel),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: const Color(0xFF58D0A4),
                foregroundColor: const Color(0xFF07130F),
              ),
            ),
            itemBuilder: (context, index) {
              final key = _extraOrder[index];
              final isBuiltIn = isVanQuoteBuiltInExtraKey(key);
              final customRow = isBuiltIn ? null : _customRowForKey(key);
              if (!isBuiltIn && customRow == null) {
                return SizedBox.shrink(
                  key: ValueKey('missing-quote-extra-row-$key'),
                );
              }
              if (isBuiltIn) {
                _ensureBuiltInControllers(key);
              }
              return Padding(
                key: ValueKey('quote-extra-row-$key'),
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Icon(
                          Icons.drag_handle,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SavedExtraEditorRow(
                        title: isBuiltIn
                            ? kVanQuoteExtraDefaultLabels[key] ?? 'Extra'
                            : 'Custom extra',
                        fieldKey: key,
                        labelController: isBuiltIn
                            ? _labelControllers[key]!
                            : customRow!.labelController,
                        priceController: isBuiltIn
                            ? _priceControllers[key]!
                            : customRow!.priceController,
                        labelFocusNode: isBuiltIn
                            ? _labelFocusNodes[key]!
                            : customRow!.labelFocusNode,
                        priceFocusNode: isBuiltIn
                            ? _priceFocusNodes[key]!
                            : customRow!.priceFocusNode,
                        enabled: isBuiltIn
                            ? _enabledValues[key] ?? true
                            : customRow!.enabled,
                        onEnabledChanged: (value) {
                          if (isBuiltIn) {
                            _enabledValues[key] = value;
                          } else {
                            customRow!.enabled = value;
                          }
                        },
                        onDelete: isBuiltIn
                            ? () => _deleteBuiltInExtra(key)
                            : () => _deleteCustomExtra(customRow!),
                        deleteTooltip: isBuiltIn
                            ? 'Delete built-in extra'
                            : 'Delete custom extra',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SavedExtraEditorRow extends StatefulWidget {
  const _SavedExtraEditorRow({
    required this.title,
    required this.fieldKey,
    required this.labelController,
    required this.priceController,
    required this.labelFocusNode,
    required this.priceFocusNode,
    required this.enabled,
    required this.onEnabledChanged,
    this.onDelete,
    this.deleteTooltip = 'Delete custom extra',
  });

  final String title;
  final String fieldKey;
  final TextEditingController labelController;
  final TextEditingController priceController;
  final FocusNode labelFocusNode;
  final FocusNode priceFocusNode;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback? onDelete;
  final String deleteTooltip;

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
              if (widget.onDelete != null) ...[
                IconButton(
                  tooltip: widget.deleteTooltip,
                  onPressed: widget.onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
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
                  key: ValueKey('quote-extra-label-${widget.fieldKey}'),
                  controller: widget.labelController,
                  focusNode: widget.labelFocusNode,
                  style: kVanMateFieldTextStyle,
                  decoration: vanMateFieldDecoration(
                    label: 'Label',
                    hintText: widget.title,
                  ),
                ),
                TextField(
                  key: ValueKey('quote-extra-price-${widget.fieldKey}'),
                  controller: widget.priceController,
                  focusNode: widget.priceFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const <TextInputFormatter>[
                    _CurrencyInputFormatter(),
                  ],
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _EditableCustomExtra {
  _EditableCustomExtra({
    required this.key,
    required this.labelController,
    required this.priceController,
    required this.labelFocusNode,
    required this.priceFocusNode,
    required this.enabled,
  });

  factory _EditableCustomExtra.fromExtra(VanQuoteExtraDefault extra) {
    return _EditableCustomExtra(
      key: extra.key,
      labelController: TextEditingController(text: extra.resolvedLabel),
      priceController: TextEditingController(
        text: extra.defaultPrice == 0
            ? '0'
            : extra.defaultPrice.toStringAsFixed(2),
      ),
      labelFocusNode: FocusNode(debugLabel: 'quote-extra-${extra.key}-label'),
      priceFocusNode: FocusNode(debugLabel: 'quote-extra-${extra.key}-price'),
      enabled: extra.enabled,
    );
  }

  factory _EditableCustomExtra.blank({required String key}) {
    return _EditableCustomExtra(
      key: key,
      labelController: TextEditingController(),
      priceController: TextEditingController(text: '0'),
      labelFocusNode: FocusNode(debugLabel: 'quote-extra-$key-label'),
      priceFocusNode: FocusNode(debugLabel: 'quote-extra-$key-price'),
      enabled: true,
    );
  }

  final String key;
  final TextEditingController labelController;
  final TextEditingController priceController;
  final FocusNode labelFocusNode;
  final FocusNode priceFocusNode;
  bool enabled;

  void dispose() {
    labelController.dispose();
    priceController.dispose();
    labelFocusNode.dispose();
    priceFocusNode.dispose();
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  const _CurrencyInputFormatter();

  static final RegExp _validCurrency = RegExp(r'^\d*(?:\.\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return _validCurrency.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
