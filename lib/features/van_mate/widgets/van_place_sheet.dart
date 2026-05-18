import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/van_place.dart';

class VanPlaceDraft {
  final String name;
  final String address;
  final String postcodeArea;
  final String deliveryNote;
  final String warningNote;
  final String privateInfo;
  final VanPlaceType placeType;
  final double? latitude;
  final double? longitude;

  const VanPlaceDraft({
    required this.name,
    required this.address,
    required this.postcodeArea,
    required this.deliveryNote,
    required this.warningNote,
    required this.privateInfo,
    required this.placeType,
    required this.latitude,
    required this.longitude,
  });
}

Future<VanPlaceDraft?> showVanPlaceEditorSheet(
  BuildContext context, {
  VanPlace? initialPlace,
}) {
  final nameController = TextEditingController(text: initialPlace?.name ?? '');
  final addressController = TextEditingController(
    text: initialPlace?.address ?? '',
  );
  final postcodeController = TextEditingController(
    text: initialPlace?.postcodeArea ?? '',
  );
  final deliveryNoteController = TextEditingController(
    text: initialPlace?.deliveryNote ?? '',
  );
  final warningNoteController = TextEditingController(
    text: initialPlace?.warningNote ?? '',
  );
  final privateInfoController = TextEditingController(
    text: initialPlace?.privateInfo ?? '',
  );
  final latitudeController = TextEditingController(
    text: initialPlace?.latitude?.toString() ?? '',
  );
  final longitudeController = TextEditingController(
    text: initialPlace?.longitude?.toString() ?? '',
  );

  return showModalBottomSheet<VanPlaceDraft>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      var selectedType = initialPlace?.placeType ?? VanPlaceType.shop;
      String? validationMessage;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          void submit() {
            final trimmedName = nameController.text.trim();
            final trimmedPostcode = postcodeController.text.trim();
            final trimmedLatitude = latitudeController.text.trim();
            final trimmedLongitude = longitudeController.text.trim();

            if (trimmedName.isEmpty || trimmedPostcode.isEmpty) {
              setSheetState(() {
                validationMessage =
                    'Add at least a drop name and postcode / area.';
              });
              return;
            }

            final latitude = trimmedLatitude.isEmpty
                ? null
                : double.tryParse(trimmedLatitude);
            final longitude = trimmedLongitude.isEmpty
                ? null
                : double.tryParse(trimmedLongitude);

            final hasOnlyOneCoordinate =
                (latitude == null) != (longitude == null);
            if (hasOnlyOneCoordinate) {
              setSheetState(() {
                validationMessage =
                    'Add both latitude and longitude or leave both blank.';
              });
              return;
            }

            final hasInvalidCoordinate =
                (trimmedLatitude.isNotEmpty && latitude == null) ||
                (trimmedLongitude.isNotEmpty && longitude == null);
            if (hasInvalidCoordinate) {
              setSheetState(() {
                validationMessage =
                    'Latitude and longitude need to be valid numbers.';
              });
              return;
            }

            Navigator.of(context).pop(
              VanPlaceDraft(
                name: trimmedName,
                address: addressController.text.trim(),
                postcodeArea: trimmedPostcode,
                deliveryNote: deliveryNoteController.text.trim(),
                warningNote: warningNoteController.text.trim(),
                privateInfo: privateInfoController.text.trim(),
                placeType: selectedType,
                latitude: latitude,
                longitude: longitude,
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              32,
              12,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 12,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF11203A).withValues(alpha: 0.96),
                        const Color(0xFF0A1526).withValues(alpha: 0.96),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.30),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        initialPlace == null
                                            ? 'Add Van Drop'
                                            : 'Edit Van Drop',
                                        style: const TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Saved drops go straight into van_places so they are ready for routes and map pins.',
                                        style: TextStyle(
                                          fontSize: 12.8,
                                          height: 1.45,
                                          color: Colors.white.withValues(
                                            alpha: 0.70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _VanSheetField(
                              controller: nameController,
                              label: 'Drop name',
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            _VanSheetField(
                              controller: addressController,
                              label: 'Address',
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            _VanSheetField(
                              controller: postcodeController,
                              label: 'Postcode / area',
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            _VanTypeDropdown(
                              selectedType: selectedType,
                              onChanged: (nextType) {
                                if (nextType == null) return;
                                setSheetState(() {
                                  selectedType = nextType;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            _VanSheetField(
                              controller: deliveryNoteController,
                              label: 'Delivery note',
                              textInputAction: TextInputAction.newline,
                              minLines: 2,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                            _VanSheetField(
                              controller: warningNoteController,
                              label: 'Warning note',
                              textInputAction: TextInputAction.newline,
                              minLines: 2,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                            _VanSheetField(
                              controller: privateInfoController,
                              label: 'Private info',
                              helperText:
                                  'Gate codes, key codes, access notes, or private driver notes. This will not be shared publicly.',
                              hintText:
                                  'Gate code, key safe code, alarm note, or private note',
                              textInputAction: TextInputAction.newline,
                              minLines: 2,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _VanSheetField(
                                    controller: latitudeController,
                                    label: 'Latitude',
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          signed: true,
                                          decimal: true,
                                        ),
                                    textInputAction: TextInputAction.next,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _VanSheetField(
                                    controller: longitudeController,
                                    label: 'Longitude',
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          signed: true,
                                          decimal: true,
                                        ),
                                    textInputAction: TextInputAction.done,
                                  ),
                                ),
                              ],
                            ),
                            if (validationMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                validationMessage!,
                                style: const TextStyle(
                                  fontSize: 12.6,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFFA8A8),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A7DFF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Text(
                                  initialPlace == null
                                      ? 'Save Drop'
                                      : 'Save Changes',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
        },
      );
    },
  ).whenComplete(() {
    nameController.dispose();
    addressController.dispose();
    postcodeController.dispose();
    deliveryNoteController.dispose();
    warningNoteController.dispose();
    privateInfoController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
  });
}

class _VanSheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? helperText;
  final String? hintText;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;

  const _VanSheetField({
    required this.controller,
    required this.label,
    this.helperText,
    this.hintText,
    this.textInputAction,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.68),
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF4A7DFF)),
        ),
        alignLabelWithHint: minLines > 1,
        helperText: helperText,
        helperMaxLines: 3,
        helperStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.58),
          fontWeight: FontWeight.w500,
        ),
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.36),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _VanTypeDropdown extends StatelessWidget {
  final VanPlaceType selectedType;
  final ValueChanged<VanPlaceType?> onChanged;

  const _VanTypeDropdown({required this.selectedType, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<VanPlaceType>(
      initialValue: selectedType,
      onChanged: onChanged,
      dropdownColor: const Color(0xFF0E182A),
      iconEnabledColor: Colors.white,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        labelText: 'Drop type',
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.68),
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF4A7DFF)),
        ),
      ),
      items: VanPlaceType.values
          .map((type) {
            return DropdownMenuItem<VanPlaceType>(
              value: type,
              child: Text(type.label),
            );
          })
          .toList(growable: false),
    );
  }
}
