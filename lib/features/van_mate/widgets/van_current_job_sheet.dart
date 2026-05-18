import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../helpers/van_live_pin_request.dart';
import '../models/van_route_stop.dart';

enum VanJobActionType { delivered, failed }

class VanJobActionResult {
  final VanJobActionType type;
  final String failureNote;

  const VanJobActionResult.delivered()
    : type = VanJobActionType.delivered,
      failureNote = '';

  const VanJobActionResult.failed({this.failureNote = ''})
    : type = VanJobActionType.failed;
}

Future<VanJobActionResult?> showVanCurrentJobSheet(
  BuildContext context, {
  required VanRouteStop stop,
  required Future<void> Function() onNavigate,
}) {
  final noteController = TextEditingController();

  return showModalBottomSheet<VanJobActionResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final bottomSafeInset = MediaQuery.paddingOf(sheetContext).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          48,
          12,
          MediaQuery.viewInsetsOf(sheetContext).bottom + bottomSafeInset + 28,
        ),
        child: _VanJobSheetBody(
          stop: stop,
          noteController: noteController,
          onNavigate: onNavigate,
        ),
      );
    },
  ).whenComplete(noteController.dispose);
}

class _VanJobSheetBody extends StatefulWidget {
  final VanRouteStop stop;
  final TextEditingController noteController;
  final Future<void> Function() onNavigate;

  const _VanJobSheetBody({
    required this.stop,
    required this.noteController,
    required this.onNavigate,
  });

  @override
  State<_VanJobSheetBody> createState() => _VanJobSheetBodyState();
}

class _VanJobSheetBodyState extends State<_VanJobSheetBody> {
  final FocusNode _failureNoteFocusNode = FocusNode();
  bool _showFailureNote = false;

  @override
  void dispose() {
    _failureNoteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stop = widget.stop;
    final accent = stop.isFailed
        ? const Color(0xFFFF9C7C)
        : stop.isDone
        ? const Color(0xFF58D0A4)
        : const Color(0xFF4A7DFF);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.76;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        stop.name,
                        style: const TextStyle(
                          fontSize: 20.2,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  stop.postcodeArea,
                  style: TextStyle(
                    fontSize: 12.9,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: accent.withValues(alpha: 0.12),
                    border: Border.all(color: accent.withValues(alpha: 0.22)),
                  ),
                  child: Text(
                    stop.isQueued ? 'Current' : stop.status.storageValue,
                    style: TextStyle(
                      fontSize: 11.4,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(bottom: bottomInset > 0 ? 10 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (stop.address.trim().isNotEmpty) ...[
                          _VanInfoLine(label: 'Address', value: stop.address),
                          const SizedBox(height: 7),
                        ],
                        _VanInfoLine(
                          label: 'Delivery note',
                          value: stop.deliveryNote.isEmpty
                              ? 'No delivery note saved.'
                              : stop.deliveryNote,
                        ),
                        if (stop.warningNote.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _VanInfoLine(
                            label: 'Warning note',
                            value: stop.warningNote,
                            accent: const Color(0xFFFFC38C),
                          ),
                        ],
                        const SizedBox(height: 7),
                        _VanInfoLine(
                          label: 'Place type',
                          value: stop.placeType.label,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Struggling to find the entrance? Send a one-time link so the customer/site can share the correct drop-off pin.',
                          style: TextStyle(
                            fontSize: 12.0,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 7),
                        _VanActionButton(
                          label: 'Request exact pin',
                          expand: true,
                          toned: true,
                          accentColor: const Color(0xFF4A7DFF),
                          icon: Icons.share_outlined,
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            unawaited(
                              requestVanLivePinForStop(context, stop)
                                  .then((_) {}),
                            );
                          },
                        ),
                        const SizedBox(height: 7),
                        _VanActionButton(
                          label: 'Copy request link',
                          expand: true,
                          compact: true,
                          toned: true,
                          accentColor: const Color(0xFF7EA2FF),
                          icon: Icons.copy_rounded,
                          onTap: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            unawaited(
                              copyVanLivePinRequestForStop(context, stop)
                                  .then((_) {}),
                            );
                          },
                        ),
                        const SizedBox(height: 7),
                        _VanPlaceholderPanel(
                          onAddSignature: () => _showPlaceholderMessage(
                            context,
                            'Signature capture can be added here next.',
                          ),
                          onAddPhoto: () => _showPlaceholderMessage(
                            context,
                            'Photo proof can be added here next.',
                          ),
                          onAddDeliveryNote: () => _showPlaceholderMessage(
                            context,
                            'Extra delivery notes can be added here later.',
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          child: _showFailureNote
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Failure note',
                                        style: TextStyle(
                                          fontSize: 11.6,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                          color: Colors.white.withValues(
                                            alpha: 0.72,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      TextField(
                                        controller: widget.noteController,
                                        focusNode: _failureNoteFocusNode,
                                        minLines: 2,
                                        maxLines: 3,
                                        textInputAction: TextInputAction.done,
                                        scrollPadding: EdgeInsets.fromLTRB(
                                          16,
                                          24,
                                          16,
                                          bottomInset + 110,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Add a short failure note if needed',
                                          hintStyle: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.42,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.10,
                                              ),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.white.withValues(
                                                alpha: 0.10,
                                              ),
                                            ),
                                          ),
                                          focusedBorder:
                                              const OutlineInputBorder(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(16),
                                                ),
                                                borderSide: BorderSide(
                                                  color: Color(0xFF5D8BFF),
                                                ),
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackActions = constraints.maxWidth < 430;
                    final navigateButton = _VanActionButton(
                      label: 'Navigate',
                      filled: true,
                      expand: true,
                      onTap: () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        await widget.onNavigate();
                      },
                    );
                    final doneButton = _VanActionButton(
                      label: 'Done',
                      filled: true,
                      expand: true,
                      accentGradient: const [
                        Color(0xFF2FBC88),
                        Color(0xFF58D0A4),
                      ],
                      onTap: () {
                        Navigator.of(
                          context,
                        ).pop(const VanJobActionResult.delivered());
                      },
                    );
                    final failedButton = _VanActionButton(
                      label: _showFailureNote ? 'Confirm Failed' : 'Failed',
                      expand: true,
                      toned: true,
                      accentColor: const Color(0xFFFF8A72),
                      onTap: _handleFailedTap,
                    );

                    if (stackActions) {
                      return Column(
                        children: [
                          navigateButton,
                          const SizedBox(height: 8),
                          doneButton,
                          const SizedBox(height: 8),
                          failedButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: navigateButton),
                        const SizedBox(width: 8),
                        Expanded(child: doneButton),
                        const SizedBox(width: 8),
                        Expanded(child: failedButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPlaceholderMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleFailedTap() {
    if (!_showFailureNote) {
      setState(() {
        _showFailureNote = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _failureNoteFocusNode.requestFocus();
        }
      });
      return;
    }

    Navigator.of(context).pop(
      VanJobActionResult.failed(failureNote: widget.noteController.text.trim()),
    );
  }
}

class _VanInfoLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;

  const _VanInfoLine({required this.label, required this.value, this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.2,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.0,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: accent ?? Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _VanPlaceholderPanel extends StatelessWidget {
  final VoidCallback onAddSignature;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddDeliveryNote;

  const _VanPlaceholderPanel({
    required this.onAddSignature,
    required this.onAddPhoto,
    required this.onAddDeliveryNote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proof of Delivery',
            style: TextStyle(
              fontSize: 14.8,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Signature, photo proof, and extra notes can be added here later.',
            style: TextStyle(
              fontSize: 12.0,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _VanActionButton(
                label: 'Add Signature',
                compact: true,
                onTap: onAddSignature,
              ),
              _VanActionButton(
                label: 'Add Photo',
                compact: true,
                onTap: onAddPhoto,
              ),
              _VanActionButton(
                label: 'Add Note',
                compact: true,
                onTap: onAddDeliveryNote,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VanActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final bool expand;
  final bool compact;
  final bool toned;
  final List<Color>? accentGradient;
  final Color? accentColor;
  final IconData? icon;
  final VoidCallback onTap;

  const _VanActionButton({
    required this.label,
    this.filled = false,
    this.expand = false,
    this.compact = false,
    this.toned = false,
    this.accentGradient,
    this.accentColor,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          height: compact ? 36 : 42,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 11,
            vertical: compact ? 6 : 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: filled
                ? LinearGradient(
                    colors:
                        accentGradient ??
                        const [Color(0xFF3C66EE), Color(0xFF5D8BFF)],
                  )
                : null,
            color: filled
                ? null
                : toned
                ? (accentColor ?? const Color(0xFF4A7DFF)).withValues(
                    alpha: 0.10,
                  )
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: filled
                  ? Colors.white.withValues(alpha: 0.12)
                  : toned
                  ? (accentColor ?? const Color(0xFF4A7DFF)).withValues(
                      alpha: 0.18,
                    )
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16.5, color: Colors.white),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: compact ? 11.8 : 12.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
