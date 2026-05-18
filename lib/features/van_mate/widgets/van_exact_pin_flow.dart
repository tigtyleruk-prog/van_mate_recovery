import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class VanExactPinSelection {
  const VanExactPinSelection({
    required this.selectedPin,
    this.note = '',
  });

  final LatLng selectedPin;
  final String note;
}

const LatLng _kVanMateUkFallbackCenter = LatLng(53.4808, -2.2426);

bool _isValidLatLng(LatLng value) {
  if (value.latitude == 0 && value.longitude == 0) {
    return false;
  }

  return value.latitude >= -90 &&
      value.latitude <= 90 &&
      value.longitude >= -180 &&
      value.longitude <= 180;
}

bool _looksLikeUkCoordinate(LatLng value) {
  if (!_isValidLatLng(value)) {
    return false;
  }

  return value.latitude >= 49.0 &&
      value.latitude <= 61.8 &&
      value.longitude >= -11.0 &&
      value.longitude <= 3.8;
}

LatLng _sanitizePickerTarget(LatLng candidate) {
  if (_looksLikeUkCoordinate(candidate)) {
    return candidate;
  }

  return _kVanMateUkFallbackCenter;
}

Future<bool?> showVanExactPinConfirmDialog(
  BuildContext context, {
  required String body,
}) async {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF0E1320),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: const Text(
          'Are you at the exact pickup/drop-off point now?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          body,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.76),
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4A7DFF),
            ),
            child: const Text('Save exact pin'),
          ),
        ],
      );
    },
  );
}

Future<VanExactPinSelection?> showVanExactPinMapPickerSheet(
  BuildContext context, {
  required CameraPosition initialCameraPosition,
  LatLng? initialSelectedPin,
  String title = 'Choose the pickup/drop-off point',
  String message =
      'Move the map so the crosshair sits on the entrance, loading bay, driveway, gate or exact place the driver should go.',
  String primaryLabel = 'Use pin',
}) {
  return showModalBottomSheet<VanExactPinSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _VanExactPinMapPickerSheet(
        initialCameraPosition: initialCameraPosition,
        initialSelectedPin: initialSelectedPin,
        title: title,
        message: message,
        primaryLabel: primaryLabel,
      );
    },
  );
}

class _VanExactPinMapPickerSheet extends StatefulWidget {
  const _VanExactPinMapPickerSheet({
    required this.initialCameraPosition,
    required this.initialSelectedPin,
    required this.title,
    required this.message,
    required this.primaryLabel,
  });

  final CameraPosition initialCameraPosition;
  final LatLng? initialSelectedPin;
  final String title;
  final String message;
  final String primaryLabel;

  @override
  State<_VanExactPinMapPickerSheet> createState() =>
      _VanExactPinMapPickerSheetState();
}

class _VanExactPinMapPickerSheetState
    extends State<_VanExactPinMapPickerSheet> {
  late CameraPosition _cameraPosition;
  late LatLng _selectedPin;
  GoogleMapController? _mapController;
  bool _mapReady = false;
  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    final explicitPin = widget.initialSelectedPin;
    final sanitizedTarget = _isValidLatLng(explicitPin ?? widget.initialCameraPosition.target)
        ? (explicitPin ?? widget.initialCameraPosition.target)
        : _sanitizePickerTarget(widget.initialCameraPosition.target);
    _cameraPosition = CameraPosition(
      target: sanitizedTarget,
      zoom: widget.initialCameraPosition.zoom,
      bearing: widget.initialCameraPosition.bearing,
      tilt: widget.initialCameraPosition.tilt,
    );
    _selectedPin = sanitizedTarget;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _completeSelection() async {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(
      VanExactPinSelection(
        selectedPin: _selectedPin,
      ),
    );
  }

  void _syncSelectedPinFromCamera() {
    setState(() {
      _selectedPin = _cameraPosition.target;
      _isMoving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsGoogleMapsPlatform()) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _VanExactPinSheetFrame(
              title: widget.title,
              message:
                  'Map picker unavailable here. Please open this on Android, iOS, or web.',
              primaryLabel: widget.primaryLabel,
              onPrimary: null,
              secondaryLabel: 'Cancel',
              onSecondary: () => Navigator.of(context).pop(),
              child: const _VanExactPinUnavailableBody(),
            ),
          ),
        );
    }

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: double.infinity,
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
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.message,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.74),
                                    height: 1.42,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            _VanExactPinCoordChip(
                              selectedPin: _selectedPin,
                              isMoving: _isMoving,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                GoogleMap(
                                  initialCameraPosition: _cameraPosition,
                                  onMapCreated: (controller) {
                                    _mapController = controller;
                                    if (!_mapReady && mounted) {
                                      setState(() {
                                        _mapReady = true;
                                      });
                                    }
                                  },
                                  onCameraMoveStarted: () {
                                    if (!_isMoving && mounted) {
                                      setState(() {
                                        _isMoving = true;
                                      });
                                    }
                                  },
                                  onCameraMove: (position) {
                                    _cameraPosition = position;
                                  },
                                  onCameraIdle: _syncSelectedPinFromCamera,
                                  myLocationButtonEnabled: false,
                                  myLocationEnabled: false,
                                  zoomControlsEnabled: false,
                                  mapToolbarEnabled: false,
                                  compassEnabled: false,
                                  indoorViewEnabled: false,
                                  rotateGesturesEnabled: false,
                                  tiltGesturesEnabled: false,
                                  gestureRecognizers: <Factory<
                                    OneSequenceGestureRecognizer
                                  >>{
                                    Factory<OneSequenceGestureRecognizer>(
                                      () => EagerGestureRecognizer(),
                                    ),
                                  },
                                ),
                                IgnorePointer(
                                  child: Center(
                                    child: Icon(
                                      Icons.location_on_rounded,
                                      size: 54,
                                      color: const Color(
                                        0xFFFFC38C,
                                      ).withValues(alpha: 0.96),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  top: 12,
                                  child: IgnorePointer(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: Colors.black.withValues(
                                          alpha: 0.52,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.12,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        _isMoving
                                            ? 'Move the map, then release to place the pin.'
                                            : 'Drag the map until the crosshair sits on the exact point.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 11.8,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _mapReady ? _completeSelection : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A7DFF),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Text(widget.primaryLabel),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.16),
                                  ),
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> showVanExactPinNoteSheet(
  BuildContext context, {
  String title = 'Add entrance / gate note?',
  String message =
      'Optional. Add a short note to help the driver find the exact entrance, loading bay, driveway or gate.',
  String primaryLabel = 'Save pin',
  String secondaryLabel = 'Skip note',
  String hintText = 'Add a note for the driver...',
  String initialNote = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _VanExactPinNoteSheet(
        title: title,
        message: message,
        primaryLabel: primaryLabel,
        secondaryLabel: secondaryLabel,
        hintText: hintText,
        initialNote: initialNote,
      );
    },
  );
}

class _VanExactPinSheetFrame extends StatelessWidget {
  const _VanExactPinSheetFrame({
    required this.title,
    required this.message,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final String title;
  final String message;
  final Widget child;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.74),
                  height: 1.42,
                ),
              ),
              const SizedBox(height: 14),
              child,
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4A7DFF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(primaryLabel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondary,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(secondaryLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VanExactPinNoteSheet extends StatefulWidget {
  const _VanExactPinNoteSheet({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.hintText,
    required this.initialNote,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final String secondaryLabel;
  final String hintText;
  final String initialNote;

  @override
  State<_VanExactPinNoteSheet> createState() => _VanExactPinNoteSheetState();
}

class _VanExactPinNoteSheetState extends State<_VanExactPinNoteSheet> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _saveNote() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(_noteController.text.trim());
  }

  void _skipNote() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop('');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.74),
                      height: 1.42,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: const Color(0xFF4A7DFF)
                              .withValues(alpha: 0.88),
                          width: 1.3,
                        ),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    keyboardType: TextInputType.text,
                    onSubmitted: (_) => _saveNote(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _saveNote,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4A7DFF),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(widget.primaryLabel),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _skipNote,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(widget.secondaryLabel),
                        ),
                      ),
                    ],
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

class _VanExactPinUnavailableBody extends StatelessWidget {
  const _VanExactPinUnavailableBody();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: const Text(
        'Map picker unavailable here.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _VanExactPinCoordChip extends StatelessWidget {
  const _VanExactPinCoordChip({
    required this.selectedPin,
    required this.isMoving,
  });

  final LatLng selectedPin;
  final bool isMoving;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.36),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          const Icon(Icons.gps_fixed_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMoving
                  ? 'Crosshair will lock on release.'
                  : '${selectedPin.latitude.toStringAsFixed(5)}, ${selectedPin.longitude.toStringAsFixed(5)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _supportsGoogleMapsPlatform() {
  if (kIsWeb) {
    return true;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    default:
      return false;
  }
}
