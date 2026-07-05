import 'dart:math' as math;

import 'package:flutter/material.dart';

Future<int?> showVanDurationPickerSheet({
  required BuildContext context,
  required int initialMinutes,
  required String Function(int minutes) durationLabel,
  String? title,
  List<int> quickOptions = const <int>[30, 60, 120, 240],
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return VanDurationPickerSheet(
        initialMinutes: initialMinutes,
        durationLabel: durationLabel,
        title: title,
        quickOptions: quickOptions,
      );
    },
  );
}

class VanDurationPickerSheet extends StatefulWidget {
  const VanDurationPickerSheet({
    super.key,
    required this.initialMinutes,
    required this.durationLabel,
    this.title,
    this.quickOptions = const <int>[30, 60, 120, 240],
  });

  final int initialMinutes;
  final String Function(int minutes) durationLabel;
  final String? title;
  final List<int> quickOptions;

  @override
  State<VanDurationPickerSheet> createState() => _VanDurationPickerSheetState();
}

class _VanDurationPickerSheetState extends State<VanDurationPickerSheet> {
  late final TextEditingController _customController;
  final FocusNode _customFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController(
      text: widget.initialMinutes > 0 ? widget.initialMinutes.toString() : '',
    );
  }

  @override
  void dispose() {
    _customFocusNode.dispose();
    _customController.dispose();
    super.dispose();
  }

  void _submitCustomDuration() {
    Navigator.of(context).pop(int.tryParse(_customController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final safeBottom = mediaQuery.padding.bottom;
    final sheetHeight = math.min(
      mediaQuery.size.height * 0.9,
      math.max(
        0.0,
        mediaQuery.size.height - keyboardInset - mediaQuery.padding.top - 12,
      ),
    );

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: sheetHeight,
            child: Material(
              color: const Color(0xFF13233A),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + safeBottom),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.manual,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.title != null) ...[
                              Text(
                                widget.title!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            for (final option in widget.quickOptions)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: () => Navigator.of(context).pop(option),
                                title: Text(
                                  widget.durationLabel(option),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _customController,
                          focusNode: _customFocusNode,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submitCustomDuration(),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Custom minutes',
                            labelStyle: TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: _submitCustomDuration,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                          child: const Text('Use custom duration'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
