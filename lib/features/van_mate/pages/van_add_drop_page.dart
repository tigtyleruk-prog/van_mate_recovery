import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_live_pin_request.dart';
import '../models/van_pin_request.dart';
import '../models/van_place.dart';
import '../services/places_autocomplete_controller.dart';
import '../services/places_search_service.dart';
import '../services/van_first_use_help_service.dart';
import '../services/van_pin_request_service.dart';
import '../services/van_storage_service.dart';
import 'van_map_page.dart';
import '../widgets/van_exact_pin_flow.dart';
import '../widgets/van_first_use_help_dialog.dart';

// ignore_for_file: unused_field, unused_element

class VanAddDropPageResult {
  const VanAddDropPageResult({required this.place, required this.wasEdit});

  final VanPlace place;
  final bool wasEdit;
}

class VanAddDropPage extends StatefulWidget {
  const VanAddDropPage({
    super.key,
    required this.storage,
    required this.currentUserId,
    this.initialPlace,
    this.initialSelectedPin,
    this.initialDeliveryNote,
    this.allowMissingExactPin = false,
  });

  final VanStorageService storage;
  final String currentUserId;
  final VanPlace? initialPlace;
  final LatLng? initialSelectedPin;
  final String? initialDeliveryNote;
  final bool allowMissingExactPin;

  @override
  State<VanAddDropPage> createState() => _VanAddDropPageState();
}

class _VanAddDropPageState extends State<VanAddDropPage> {
  static const LatLng _defaultCenter = LatLng(52.4862, -1.8904);
  static const double _minMapZoom = 4;
  static const double _maxMapZoom = 20;

  late final TextEditingController _searchController;
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _postcodeController;
  late final TextEditingController _deliveryNoteController;
  late final TextEditingController _warningNoteController;
  late final TextEditingController _privateInfoController;
  late final TextEditingController _phoneNumberController;
  late final ScrollController _pageScrollController;
  late final FocusNode _nameFocusNode;
  late final FocusNode _addressFocusNode;
  late final FocusNode _postcodeFocusNode;
  late final FocusNode _deliveryNoteFocusNode;
  late final FocusNode _warningNoteFocusNode;
  late final FocusNode _privateInfoFocusNode;
  late final FocusNode _latitudeFocusNode;
  late final FocusNode _longitudeFocusNode;
  late final PlacesAutocompleteController _autocompleteController;
  Stream<VanPinRequest?>? _latestPinRequestStream;

  late VanPlaceType _selectedType;
  late CameraPosition _cameraPosition;
  LatLng? _selectedPin;

  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  bool _myLocationEnabled = false;
  bool _isSaving = false;
  bool _isRequestingExactPin = false;
  bool _isResolvingPin = false;
  bool _isLoadingSharedPicker = false;
  bool _selectedPinWasExplicitlyChosen = false;
  String _selectedPinSource = '';
  bool _exactPinHelpDialogVisible = false;
  String? _inlineMessage;
  String? _lastAutoAddress;
  String? _lastAutoPostcode;
  String _pinContextLabel = 'Long press to place the exact pin.';
  int _reverseGeocodeRequestId = 0;
  int _buildCount = 0;
  int _textInputCount = 0;
  List<VanPlace> _pickerPlaces = const <VanPlace>[];
  Set<Marker> _cachedSelectedPinMarkers = const <Marker>{};
  LatLng? _cachedSelectedPinMarkerPosition;
  final Map<FocusNode, GlobalKey> _focusScrollTargets =
      <FocusNode, GlobalKey>{};

  bool get _isEditing => widget.initialPlace != null;

  @override
  void initState() {
    super.initState();
    final initialPlace = widget.initialPlace;
    final draftPin = widget.initialSelectedPin;
    final initialLatLng = initialPlace != null && initialPlace.hasCoordinates
        ? LatLng(initialPlace.latitude!, initialPlace.longitude!)
        : (draftPin ?? _defaultCenter);

    _searchController = TextEditingController();
    _nameController = TextEditingController(text: initialPlace?.name ?? '');
    _addressController = TextEditingController(
      text: initialPlace?.address ?? '',
    );
    _postcodeController = TextEditingController(
      text: initialPlace?.postcodeArea ?? '',
    );
    _deliveryNoteController = TextEditingController(
      text:
          initialPlace?.deliveryNote ??
          widget.initialDeliveryNote?.trim() ??
          '',
    );
    _warningNoteController = TextEditingController(
      text: initialPlace?.warningNote ?? '',
    );
    _privateInfoController = TextEditingController(
      text: initialPlace?.privateInfo ?? '',
    );
    _phoneNumberController = TextEditingController();
    _pageScrollController = ScrollController();
    _nameFocusNode = FocusNode();
    _addressFocusNode = FocusNode();
    _postcodeFocusNode = FocusNode();
    _deliveryNoteFocusNode = FocusNode();
    _warningNoteFocusNode = FocusNode();
    _privateInfoFocusNode = FocusNode();
    _latitudeFocusNode = FocusNode();
    _longitudeFocusNode = FocusNode();
    _focusScrollTargets.addAll(<FocusNode, GlobalKey>{
      _nameFocusNode: GlobalKey(),
      _addressFocusNode: GlobalKey(),
      _postcodeFocusNode: GlobalKey(),
      _deliveryNoteFocusNode: GlobalKey(),
      _warningNoteFocusNode: GlobalKey(),
      _privateInfoFocusNode: GlobalKey(),
      _latitudeFocusNode: GlobalKey(),
      _longitudeFocusNode: GlobalKey(),
    });
    _autocompleteController = PlacesAutocompleteController(
      searchService: PlacesSearchService(),
    );
    _selectedType = initialPlace?.placeType ?? VanPlaceType.shop;
    _selectedPin = initialPlace != null && initialPlace.hasCoordinates
        ? initialLatLng
        : draftPin;
    _selectedPinSource = initialPlace?.exactPinSource.trim() ?? '';
    _selectedPinWasExplicitlyChosen = _isExplicitInitialSelectedPin(
      initialPlace,
      draftPin,
    );
    _cameraPosition = CameraPosition(target: initialLatLng, zoom: 15.4);
    _pinContextLabel = initialPlace != null
        ? 'Long press again to refine the saved pin.'
        : draftPin != null
        ? 'Pin loaded from the map. Long press again to move it.'
        : (widget.initialDeliveryNote?.trim().isNotEmpty ?? false)
        ? 'Location note loaded. Add the details, then set the exact pin later.'
        : 'Optional: open the picker if you already know the entrance or bay.';
    if (initialPlace != null) {
      _latestPinRequestStream = VanPinRequestService.instance
          .watchLatestRequestForDropId(initialPlace.id);
    }

    if ((initialPlace != null && initialPlace.hasCoordinates) ||
        draftPin != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_reverseGeocodeForPin(initialLatLng, updateMessage: false));
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _postcodeController.dispose();
    _deliveryNoteController.dispose();
    _warningNoteController.dispose();
    _privateInfoController.dispose();
    _phoneNumberController.dispose();
    _pageScrollController.dispose();
    _nameFocusNode.dispose();
    _addressFocusNode.dispose();
    _postcodeFocusNode.dispose();
    _deliveryNoteFocusNode.dispose();
    _warningNoteFocusNode.dispose();
    _privateInfoFocusNode.dispose();
    _latitudeFocusNode.dispose();
    _longitudeFocusNode.dispose();
    _autocompleteController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _refreshLatestPinRequest() async {
    final initialPlace = widget.initialPlace;
    if (!_isEditing || initialPlace == null) {
      return;
    }

    setState(() {
      _latestPinRequestStream = VanPinRequestService.instance
          .watchLatestRequestForDropId(initialPlace.id);
    });
  }

  Future<void> _showRequestExactPinHelpIfNeeded() async {
    if (_exactPinHelpDialogVisible) {
      return;
    }

    final helpService = VanMateFirstUseHelpService.instance;
    await helpService.ensureLoaded();
    if (!mounted ||
        await helpService.hasSeen(
          VanMateFirstUseHelpKeys.seenRequestExactPinHelp,
        )) {
      return;
    }

    _exactPinHelpDialogVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) {
          return;
        }

        await showVanMateFirstUseHelpDialog(
          context,
          storageKey: VanMateFirstUseHelpKeys.seenRequestExactPinHelp,
          title: 'Request exact pin',
          body:
              'Send a one-time link to the customer or site so they can share the actual delivery entrance, bay, or drop-off point. It does not track them live.',
        );
      } finally {
        if (mounted) {
          _exactPinHelpDialogVisible = false;
        }
      }
    });
  }

  Future<VanPinRequest?> _requestExactPinWithHelp(
    VanPlace place, {
    String? recipientPhoneNumber,
    String? successMessage,
  }) async {
    await _showRequestExactPinHelpIfNeeded();
    if (!mounted) {
      return null;
    }

    return requestVanLivePinForPlace(
      context,
      place,
      recipientPhoneNumber: recipientPhoneNumber,
      successMessage: successMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    final bottomSafeInset = MediaQuery.viewPaddingOf(context).bottom;
    const cardSpacing = 8.0;
    const bottomBreathingRoom = 352.0;
    debugPrint(
      '[Perf] Add Drop page build #$_buildCount bottomSafeInset=$bottomSafeInset selectedPin=${_selectedPin != null}',
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.36)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  child: _VanAddDropHeader(
                    title: _isEditing ? 'Edit Drop' : 'Add Drop',
                    subtitle:
                        'Add the drop details, then set or request the exact pin.',
                    onClose: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.of(context).maybePop();
                    },
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: _pageScrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      bottomSafeInset + bottomBreathingRoom,
                    ),
                    children: [
                      SizedBox(height: cardSpacing),
                      _buildMapCard(),
                      SizedBox(height: cardSpacing),
                      _buildFormCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard() {
    return RepaintBoundary(
      child: _VanAddDropCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Exact drop pin',
                        style: TextStyle(
                          fontSize: 16.2,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Optional - set the exact entrance or bay now, pin your current location, or request it later.',
              style: TextStyle(
                fontSize: 11.9,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedPin != null) ...[
              _VanCompactNoteCard(
                label: 'Exact pin selected',
                value:
                    '${_selectedPin!.latitude.toStringAsFixed(5)}, ${_selectedPin!.longitude.toStringAsFixed(5)}',
                accent: const Color(0xFF58D0A4),
                maxLines: 1,
              ),
            ] else ...[
              _VanCompactNoteCard(
                label: 'No exact pin selected',
                value: 'You can set it now or request it later.',
                accent: const Color(0xFF7EA2FF),
                maxLines: 1,
              ),
            ],
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final pinButton = FilledButton.icon(
                  onPressed: _isSaving ? null : _pinCurrentLocation,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2FBC88),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text(
                    'Pin current location',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
                final pickerButton = FilledButton.icon(
                  onPressed: _isLoadingSharedPicker
                      ? null
                      : _openSharedPinPicker,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF29446F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isLoadingSharedPicker
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.open_in_full_rounded, size: 18),
                  label: Text(
                    _isLoadingSharedPicker ? 'Loading...' : 'Open Picker',
                    style: const TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );

                if (constraints.maxWidth < 420) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: double.infinity, child: pinButton),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: pickerButton),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: pinButton),
                    const SizedBox(width: 10),
                    Expanded(child: pickerButton),
                  ],
                );
              },
            ),
            if (_isEditing && widget.initialPlace != null) ...[
              const SizedBox(height: 9),
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
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final place = widget.initialPlace;
                    if (place == null) return;
                    await _requestExactPinWithHelp(place);
                    await _refreshLatestPinRequest();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF223B5F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text(
                    'Request exact pin',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final place = widget.initialPlace;
                    if (place == null) return;
                    await copyVanLivePinRequestForPlace(context, place);
                    await _refreshLatestPinRequest();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text(
                    'Copy request link',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return _VanAddDropCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Drop Details',
            style: TextStyle(
              fontSize: 16.2,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          if (_isEditing && _latestPinRequestStream != null)
            StreamBuilder<VanPinRequest?>(
              stream: _latestPinRequestStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint(
                    '[PinRequest] Edit Drop stream error: ${snapshot.error}',
                  );
                  return const SizedBox.shrink();
                }

                final request = snapshot.data;
                if (request == null) {
                  return _VanCompactStatusCard(
                    title: 'No exact pin request yet',
                    body:
                        'Send a one-time link if the entrance or bay is unclear.',
                    accent: const Color(0xFF7EA2FF),
                  );
                }

                final hasSavedPin = request.usedAsExactPin;
                final hasReceivedPin = request.canUseReceivedPin;
                final isNoteRequest =
                    request.status == VanPinRequestStatus.receivedNote;
                final isExpired = request.isExpired;
                final isPending =
                    request.status == VanPinRequestStatus.pending && !isExpired;
                final accent = hasSavedPin
                    ? const Color(0xFF58D0A4)
                    : isExpired
                    ? const Color(0xFFFF8A72)
                    : isNoteRequest
                    ? const Color(0xFFF8C76C)
                    : hasReceivedPin
                    ? const Color(0xFF58D0A4)
                    : const Color(0xFF4A7DFF);
                final title = hasSavedPin
                    ? 'Exact pin saved'
                    : isNoteRequest
                    ? 'Location note received'
                    : hasReceivedPin
                    ? 'Exact pin received'
                    : isExpired
                    ? 'Request expired'
                    : isPending
                    ? 'Exact pin request pending'
                    : 'Exact pin received';
                final body = hasSavedPin
                    ? 'The received pin is already applied to this drop.'
                    : isNoteRequest
                    ? (request.responseNote.trim().isNotEmpty
                          ? request.responseNote.trim()
                          : 'The customer/site sent a location note instead of coordinates.')
                    : hasReceivedPin
                    ? request.responseSourceLabel
                    : isExpired
                    ? 'This request has expired. Send a fresh one if needed.'
                    : 'Waiting for customer/site to send the pin.';

                return Column(
                  children: [
                    _VanCompactStatusCard(
                      title: title,
                      body: body,
                      accent: accent,
                    ),
                    if (isNoteRequest &&
                        request.responseNote.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      _VanCompactNoteCard(
                        label: 'Location note',
                        value: request.responseNote.trim(),
                        accent: const Color(0xFFF8C76C),
                        maxLines: 3,
                      ),
                    ],
                    if (hasReceivedPin) ...[
                      const SizedBox(height: 7),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  await _applyReceivedPinAndSave(request);
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2FBC88),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text(
                            'Use received pin',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (isNoteRequest &&
                        request.responseNote.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final note = request.responseNote.trim();
                            if (note.isEmpty) return;
                            await Clipboard.setData(ClipboardData(text: note));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(content: Text('Note copied.')),
                              );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text(
                            'Copy note',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          _VanInputField(
            controller: _nameController,
            label: 'Drop name',
            textInputAction: TextInputAction.next,
            focusNode: _nameFocusNode,
            onSubmitted: (_) => _addressFocusNode.requestFocus(),
            onChanged: (value) => _logTextInputChanged('Drop name', value),
            scrollController: _pageScrollController,
            scrollTargetKey: _focusScrollTargets[_nameFocusNode],
          ),
          const SizedBox(height: 7),
          _VanInputField(
            controller: _addressController,
            label: 'Address',
            textInputAction: TextInputAction.next,
            focusNode: _addressFocusNode,
            onSubmitted: (_) => _postcodeFocusNode.requestFocus(),
            onChanged: (value) => _logTextInputChanged('Address', value),
            scrollController: _pageScrollController,
            scrollTargetKey: _focusScrollTargets[_addressFocusNode],
          ),
          const SizedBox(height: 7),
          _VanInputField(
            controller: _postcodeController,
            label: 'Postcode / area',
            textInputAction: TextInputAction.next,
            focusNode: _postcodeFocusNode,
            onSubmitted: (_) => _deliveryNoteFocusNode.requestFocus(),
            onChanged: (value) =>
                _logTextInputChanged('Postcode / area', value),
            scrollController: _pageScrollController,
            scrollTargetKey: _focusScrollTargets[_postcodeFocusNode],
          ),
          const SizedBox(height: 7),
          _VanTypeField(
            selectedType: _selectedType,
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedType = value;
              });
            },
          ),
          const SizedBox(height: 7),
          _VanInputField(
            controller: _deliveryNoteController,
            label: 'Delivery note',
            textInputAction: TextInputAction.newline,
            minLines: 2,
            maxLines: 3,
            focusNode: _deliveryNoteFocusNode,
            onChanged: (value) => _logTextInputChanged('Delivery note', value),
            scrollController: _pageScrollController,
            scrollTargetKey: _focusScrollTargets[_deliveryNoteFocusNode],
          ),
          const SizedBox(height: 7),
          _VanInputField(
            controller: _warningNoteController,
            label: 'Warning note',
            textInputAction: TextInputAction.newline,
            minLines: 2,
            maxLines: 3,
            focusNode: _warningNoteFocusNode,
            onChanged: (value) => _logTextInputChanged('Warning note', value),
            scrollController: _pageScrollController,
            scrollTargetKey: _focusScrollTargets[_warningNoteFocusNode],
          ),
          const SizedBox(height: 7),
          _VanInputField(
            controller: _privateInfoController,
            label: 'Private info',
            textInputAction: TextInputAction.newline,
            minLines: 2,
            maxLines: 3,
            focusNode: _privateInfoFocusNode,
            onChanged: (value) => _logTextInputChanged('Private info', value),
            scrollController: _pageScrollController,
            scrollTargetKey: _focusScrollTargets[_privateInfoFocusNode],
          ),
          if (!_isEditing) ...[
            const SizedBox(height: 10),
            _buildManualExactPinRequestSection(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isBusy ? null : _saveAndRequestExactPin,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF223B5F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save & Request Exact Pin',
                        style: TextStyle(
                          fontSize: 14.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
          if (_inlineMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _inlineMessage!,
              style: const TextStyle(
                fontSize: 12.8,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFFB7B3),
              ),
            ),
          ],
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isBusy ? null : _saveDrop,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A7DFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEditing ? 'Save Changes' : 'Save Drop',
                      style: const TextStyle(
                        fontSize: 14.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _logTextInputChanged(String fieldLabel, String value) {
    _textInputCount++;
    debugPrint(
      '[Perf] Add Drop text input #$_textInputCount field=$fieldLabel length=${value.trim().length}',
    );
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _isBusy => _isSaving || _isRequestingExactPin;

  Widget _buildManualExactPinRequestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Need the exact entrance?',
          style: TextStyle(
            fontSize: 15.4,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Use this when you do not know the exact pin yet. Van Mate will save the drop first, then send a one-time pin request.',
          style: TextStyle(
            fontSize: 12.0,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 8),
        _VanInputField(
          controller: _phoneNumberController,
          label: 'Phone number optional',
          textInputAction: TextInputAction.done,
          focusNode: null,
          keyboardType: TextInputType.phone,
          autofillHints: null,
          enableSuggestions: false,
          autocorrect: false,
          onChanged: (value) =>
              _logTextInputChanged('Phone number optional', value),
          scrollController: _pageScrollController,
          scrollTargetKey: null,
        ),
        const SizedBox(height: 5),
        Text(
          'Van Mate will save the drop first, then open your share/SMS app with the request ready.',
          style: TextStyle(
            fontSize: 11.4,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }

  Set<Marker> get _selectedPinMarkers {
    final pin = _selectedPin;
    if (pin == null) {
      if (_cachedSelectedPinMarkerPosition == null &&
          _cachedSelectedPinMarkers.isEmpty) {
        return _cachedSelectedPinMarkers;
      }
      _cachedSelectedPinMarkerPosition = null;
      _cachedSelectedPinMarkers = const <Marker>{};
      return _cachedSelectedPinMarkers;
    }

    if (_cachedSelectedPinMarkerPosition == pin &&
        _cachedSelectedPinMarkers.isNotEmpty) {
      return _cachedSelectedPinMarkers;
    }

    _cachedSelectedPinMarkerPosition = pin;
    _cachedSelectedPinMarkers = <Marker>{
      Marker(markerId: const MarkerId('selected_drop_pin'), position: pin),
    };
    return _cachedSelectedPinMarkers;
  }

  void _handleSearchQueryChanged(String value) {
    if (!_autocompleteController.supportsAutocomplete) {
      return;
    }

    _autocompleteController.handleQueryChanged(
      value,
      originLatitude: _cameraPosition.target.latitude,
      originLongitude: _cameraPosition.target.longitude,
    );
  }

  Future<void> _handleSearchAction() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _setInlineMessage('Search for a place or postcode first.');
      return;
    }

    if (_autocompleteController.supportsAutocomplete) {
      FocusManager.instance.primaryFocus?.unfocus();
      await _autocompleteController.forceSearch(
        query,
        originLatitude: _cameraPosition.target.latitude,
        originLongitude: _cameraPosition.target.longitude,
      );
      if (!mounted) return;
      final errorText = _autocompleteController.errorText;
      if (errorText != null) {
        _setInlineMessage(errorText);
      } else if (_autocompleteController.suggestions.isEmpty) {
        _setInlineMessage('No Google matches were found for that search.');
      } else {
        if (mounted) {
          setState(() {
            _inlineMessage = null;
          });
        }
      }
      return;
    }

    await _searchWithFallbackGeocoding(query);
  }

  Future<void> _searchWithFallbackGeocoding(String query) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _inlineMessage = null;
    });

    try {
      final results = await locationFromAddress(query);
      if (results.isEmpty) {
        _setInlineMessage('No matching place was found for that search.');
        return;
      }

      final location = results.first;
      final pin = LatLng(location.latitude, location.longitude);
      _pinContextLabel = 'Search moved the map. Long press the exact pin.';
      await _moveCameraTo(pin, zoom: 16.2, clearSelectedPin: true);
    } catch (_) {
      _setInlineMessage('Could not search that place right now.');
    }
  }

  Future<void> _selectAutocompleteSuggestion(
    PlacesAutocompleteSuggestion suggestion,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await _autocompleteController.selectSuggestion(suggestion);
    if (!mounted) return;

    if (result == null || !result.isValid) {
      _setInlineMessage(
        _autocompleteController.errorText ??
            'Google place details could not load right now.',
      );
      return;
    }

    _searchController.value = TextEditingValue(
      text: result.primaryText,
      selection: TextSelection.collapsed(offset: result.primaryText.length),
    );

    final pin = LatLng(result.latitude, result.longitude);
    setState(() {
      _inlineMessage = null;
      _pinContextLabel = 'Google place found. Long press the exact pin.';
    });
    await _moveCameraTo(pin, zoom: 16.6, clearSelectedPin: true);
  }

  Future<void> _centerOnCurrentLocation() async {
    if (!_supportsGoogleMapsPlatform()) {
      _setInlineMessage(
        'Map controls work on Android, iOS, and web builds with Google Maps enabled.',
      );
      return;
    }

    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        _setInlineMessage(
          'Turn on location services to jump to your position.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _setInlineMessage(
          'Location permission is needed to move the Add Drop map to your position.',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _setInlineMessage(
          'Location permission is turned off for Van Mate. Enable it in app settings to use your current position.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final pin = LatLng(position.latitude, position.longitude);
      _pinContextLabel = 'Current location loaded. Long press the exact pin.';
      await _moveCameraTo(pin, zoom: 17.0, clearSelectedPin: true);
      if (!mounted) return;
      setState(() {
        _myLocationEnabled = true;
      });
    } catch (_) {
      _setInlineMessage('Could not get your current location right now.');
    }
  }

  Future<void> _pinCurrentLocation() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isLoadingSharedPicker || _isSaving || _isRequestingExactPin) {
      return;
    }

    if (!_supportsGoogleMapsPlatform()) {
      _setInlineMessage(
        'Map controls work on Android, iOS, and web builds with Google Maps enabled.',
      );
      return;
    }

    try {
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        _setInlineMessage('Turn on location services to pin your position.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _setInlineMessage(
          'Location permission is needed to pin your current position.',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _setInlineMessage(
          'Location permission is turned off for Van Mate. Enable it in app settings to use your current position.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) {
        return;
      }

      final accuracyWarning = position.accuracy > 50
          ? 'GPS accuracy looks weak. You can still save it, but check the pin later.'
          : null;
      final confirmed = await showVanExactPinConfirmDialog(
        context,
        body:
            'Use your current GPS position as the exact entrance or bay for this drop. You can adjust it later if needed.${accuracyWarning == null ? '' : '\n\n$accuracyWarning'}',
      );
      if (!mounted || confirmed != true) {
        return;
      }

      final pin = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedPin = pin;
        _selectedPinWasExplicitlyChosen = true;
        _selectedPinSource = 'current_location';
        _pinContextLabel = 'Exact pin saved from current location.';
      });
      await _reverseGeocodeForPin(pin);

      if (!mounted) {
        return;
      }
      _showSnack('Exact pin saved.');
    } catch (_) {
      _setInlineMessage(
        'Could not get your current location. Try again or use Open Picker.',
      );
    }
  }

  void _handleMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _logCameraAction('handleMapCreated', 'source=googleMapCreated');
    unawaited(_restoreCameraToCurrentView());
  }

  Future<void> _openSharedPinPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final ownerId = widget.currentUserId.trim();
    if (ownerId.isEmpty) {
      _setInlineMessage(
        'Van Mate needs a signed-in account to load saved drops.',
      );
      return;
    }

    setState(() {
      _isLoadingSharedPicker = true;
    });

    List<VanPlace> places = _pickerPlaces;
    if (places.isEmpty) {
      try {
        places = await widget.storage.getPlaces(ownerId: ownerId);
        if (mounted) {
          _pickerPlaces = places;
        }
      } catch (_) {
        if (!mounted) return;
        _setInlineMessage(
          'Could not load saved drops for the shared full-screen picker right now.',
        );
        places = _pickerPlaces;
      }
    }

    if (!mounted) return;

    final result = await Navigator.of(context).push<VanMapPageResult>(
      MaterialPageRoute<VanMapPageResult>(
        builder: (_) => VanMapPage(
          places: List<VanPlace>.from(places),
          initialCameraPosition: _cameraPosition,
          initialSelectedPin: _selectedPin,
          selectedPinActionLabel: 'Use This Pin',
          selectedPinHelperText: _isEditing
              ? 'Use this pin for this drop.'
              : 'Use this pin to add the drop.',
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _isLoadingSharedPicker = false;
    });

    if (result == null) {
      return;
    }

    _cameraPosition = result.cameraPosition;
    _selectedPin = result.selectedPin;
    _selectedPinWasExplicitlyChosen = _selectedPin != null;
    if (_selectedPin != null) {
      _selectedPinSource = 'picker';
    }
    if (_selectedPin != null) {
      setState(() {
        _inlineMessage = null;
        _pinContextLabel =
            'Pin loaded from Full Picker. Long press again to move it.';
      });
      await _restoreCameraToCurrentView();
      await _reverseGeocodeForPin(_selectedPin!);
    } else {
      await _restoreCameraToCurrentView();
    }
  }

  Future<void> _toggleMapType() async {
    setState(() {
      _mapType = _mapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await _restoreCameraToCurrentView();
  }

  Future<void> _restoreCameraToCurrentView() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    _logCameraAction('restoreCameraToCurrentView', 'source=state');
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(_cameraPosition),
    );
  }

  Future<void> _moveCameraTo(
    LatLng target, {
    double zoom = 16.0,
    bool clearSelectedPin = false,
  }) async {
    if (clearSelectedPin && mounted) {
      setState(() {
        _selectedPin = null;
        _selectedPinWasExplicitlyChosen = false;
        _selectedPinSource = '';
      });
    }

    _cameraPosition = CameraPosition(target: target, zoom: zoom);
    _logCameraAction(
      'moveCameraTo',
      'lat=${target.latitude} lng=${target.longitude} zoom=$zoom clearSelectedPin=$clearSelectedPin',
    );
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(_cameraPosition),
    );
    if (!mounted) return;
    setState(() {});
  }

  void _handleCameraIdle() {}

  Future<void> _handleMapLongPress(LatLng position) async {
    if (!mounted) return;
    _logCameraAction(
      'handleMapLongPress',
      'lat=${position.latitude} lng=${position.longitude}',
    );
    setState(() {
      _selectedPin = position;
      _selectedPinWasExplicitlyChosen = true;
      _selectedPinSource = 'manual';
      _pinContextLabel = 'Exact pin ready to save.';
    });
    await _reverseGeocodeForPin(position);
  }

  Future<void> _reverseGeocodeForPin(
    LatLng pin, {
    bool updateMessage = true,
  }) async {
    final requestId = ++_reverseGeocodeRequestId;
    if (mounted) {
      setState(() {
        _isResolvingPin = true;
      });
    }

    try {
      final placemarks = await placemarkFromCoordinates(
        pin.latitude,
        pin.longitude,
      );
      if (!mounted || requestId != _reverseGeocodeRequestId) {
        return;
      }

      if (placemarks.isEmpty) {
        setState(() {
          _isResolvingPin = false;
        });
        return;
      }

      final placemark = placemarks.first;
      final resolvedAddress = _formatAddress(placemark);
      final resolvedPostcode = _formatPostcodeOrArea(placemark);

      if (_shouldApplyAutofill(_addressController.text, _lastAutoAddress) &&
          resolvedAddress.isNotEmpty) {
        _addressController.text = resolvedAddress;
        _lastAutoAddress = resolvedAddress;
      }

      if (_shouldApplyAutofill(_postcodeController.text, _lastAutoPostcode) &&
          resolvedPostcode.isNotEmpty) {
        _postcodeController.text = resolvedPostcode;
        _lastAutoPostcode = resolvedPostcode;
      }

      setState(() {
        _isResolvingPin = false;
        if (updateMessage) {
          _inlineMessage = null;
        }
      });
    } catch (_) {
      if (!mounted || requestId != _reverseGeocodeRequestId) {
        return;
      }
      setState(() {
        _isResolvingPin = false;
      });
    }
  }

  Future<VanAddDropPageResult?> _saveDropCore({
    Future<void> Function(VanPlace savedPlace)? onSaved,
    bool allowMissingExactPin = false,
    bool allowMinimalLocationDetails = false,
  }) async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final postcodeOrArea = _postcodeController.text.trim();
    final selectedPin = _selectedPin;
    final canSaveWithoutExactPin =
        allowMissingExactPin || widget.allowMissingExactPin;

    if (name.isEmpty) {
      _setInlineMessage('Add a drop name before saving.');
      return null;
    }

    if (!allowMinimalLocationDetails && address.isEmpty) {
      _setInlineMessage('Add the drop address before saving.');
      return null;
    }

    if (!allowMinimalLocationDetails && postcodeOrArea.isEmpty) {
      _setInlineMessage('Add a postcode or area before saving.');
      return null;
    }

    if (allowMinimalLocationDetails &&
        address.isEmpty &&
        postcodeOrArea.isEmpty) {
      _setInlineMessage('Add the drop address or postcode/area before saving.');
      return null;
    }

    if (!canSaveWithoutExactPin && selectedPin == null) {
      _setInlineMessage(
        'Long press the map to place the exact drop pin before saving.',
      );
      return null;
    }

    setState(() {
      _isSaving = true;
      _inlineMessage = null;
    });

    final now = DateTime.now();
    final ownerId = widget.currentUserId.trim();
    if (ownerId.isEmpty) {
      if (!mounted) {
        return null;
      }
      _setInlineMessage('Van Mate needs a signed-in account before saving.');
      setState(() {
        _isSaving = false;
      });
      return null;
    }

    final existingPlace = widget.initialPlace;
    final latitude =
        selectedPin?.latitude ??
        (allowMissingExactPin ? existingPlace?.latitude : null);
    final longitude =
        selectedPin?.longitude ??
        (allowMissingExactPin ? existingPlace?.longitude : null);
    final trustedExactPin =
        _selectedPinWasExplicitlyChosen ||
        existingPlace?.trustedExactPin == true;
    final exactPinUpdatedAt = selectedPin != null
        ? now
        : existingPlace?.exactPinUpdatedAt;
    final exactPinSource = selectedPin != null
        ? (_selectedPinSource.isNotEmpty
              ? _selectedPinSource
              : (existingPlace?.exactPinSource.trim().isNotEmpty == true
                    ? existingPlace!.exactPinSource.trim()
                    : 'manual'))
        : existingPlace?.exactPinSource.trim() ?? '';
    final place = existingPlace == null
        ? VanPlace(
            id: widget.storage.createPlaceId(),
            ownerId: ownerId,
            name: name,
            address: address,
            postcodeArea: postcodeOrArea,
            deliveryNote: _deliveryNoteController.text.trim(),
            warningNote: _warningNoteController.text.trim(),
            privateInfo: _privateInfoController.text.trim(),
            placeType: _selectedType,
            latitude: latitude,
            longitude: longitude,
            trustedExactPin: trustedExactPin,
            exactPinUpdatedAt: exactPinUpdatedAt,
            exactPinSource: exactPinSource,
            createdAt: now,
            updatedAt: now,
            createdBy: ownerId,
          )
        : existingPlace.copyWith(
            name: name,
            address: address,
            postcodeArea: postcodeOrArea,
            deliveryNote: _deliveryNoteController.text.trim(),
            warningNote: _warningNoteController.text.trim(),
            privateInfo: _privateInfoController.text.trim(),
            placeType: _selectedType,
            latitude: latitude,
            longitude: longitude,
            trustedExactPin: trustedExactPin,
            exactPinUpdatedAt: exactPinUpdatedAt,
            exactPinSource: exactPinSource,
            updatedAt: now,
          );

    try {
      final result = await widget.storage.savePlace(
        place,
        excludePlaceId: existingPlace?.id,
      );
      if (!mounted) return null;
      final duplicatePlace = result.duplicatePlace;
      if (duplicatePlace != null) {
        final duplicateReason = result.duplicateReason?.trim() ?? '';
        final technicalLine = duplicateReason.isEmpty
            ? ''
            : '\nMatched within 6m.';
        _setInlineMessage(
          'This looks like an existing saved drop.\n\n"${duplicatePlace.name}" is already saved nearby.\n\nOpen that saved drop instead of adding a duplicate.$technicalLine',
        );
        return null;
      }

      final savedPlace = result.place ?? place;
      if (onSaved != null) {
        try {
          await onSaved(savedPlace);
        } catch (_) {
          if (mounted) {
            _setInlineMessage(
              'Drop saved, but the request status could not be updated.',
            );
          }
        }
      }

      return VanAddDropPageResult(
        place: savedPlace,
        wasEdit: existingPlace != null,
      );
    } catch (_) {
      _setInlineMessage(
        'Drop save failed in Firebase. Check connection and rules.',
      );
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  static bool _isExplicitInitialSelectedPin(
    VanPlace? initialPlace,
    LatLng? selectedPin,
  ) {
    if (selectedPin == null) {
      return false;
    }

    if (initialPlace == null || !initialPlace.hasCoordinates) {
      return true;
    }

    final initialLat = initialPlace.latitude!;
    final initialLng = initialPlace.longitude!;
    return !_sameCoordinates(
      initialLat,
      initialLng,
      selectedPin.latitude,
      selectedPin.longitude,
    );
  }

  static bool _sameCoordinates(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    return (latitudeA - latitudeB).abs() < 0.0000001 &&
        (longitudeA - longitudeB).abs() < 0.0000001;
  }

  Future<void> _saveDrop() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await _saveDropCore();
    if (!mounted || result == null) {
      return;
    }

    Navigator.of(context).pop(result);
  }

  Future<void> _saveAndRequestExactPin() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) {
      setState(() {
        _isRequestingExactPin = true;
      });
    }

    try {
      final savedResult = await _saveDropCore(
        allowMissingExactPin: true,
        allowMinimalLocationDetails: true,
      );
      if (!mounted || savedResult == null) {
        return;
      }

      final phoneNumber = _phoneNumberController.text.trim();
      final request = await _requestExactPinWithHelp(
        savedResult.place,
        recipientPhoneNumber: phoneNumber.isEmpty ? null : phoneNumber,
        successMessage: 'Drop saved. Exact pin request ready.',
      );
      if (!mounted) {
        return;
      }

      if (request == null) {
        return;
      }

      Navigator.of(context).pop(savedResult);
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingExactPin = false;
        });
      }
    }
  }

  Future<void> _applyReceivedPinAndSave(VanPinRequest request) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final responseLat = request.responseLat;
    final responseLng = request.responseLng;
    if (responseLat == null || responseLng == null) {
      _setInlineMessage('That request does not have a received pin yet.');
      return;
    }

    final receivedPin = LatLng(responseLat, responseLng);
    setState(() {
      _selectedPin = receivedPin;
      _cameraPosition = CameraPosition(
        target: receivedPin,
        zoom: _cameraPosition.zoom < 16 ? 16 : _cameraPosition.zoom,
      );
      _pinContextLabel = 'Received exact pin loaded. Save changes to keep it.';
    });

    await _saveDropCore(
      onSaved: (_) async {
        await VanPinRequestService.instance.markUsedAsExactPin(request.id);
      },
    );
  }

  void _setInlineMessage(String message) {
    if (!mounted) return;
    setState(() {
      _inlineMessage = message;
    });
  }

  Future<void> _zoomIn() => _adjustMapZoom(1);

  Future<void> _zoomOut() => _adjustMapZoom(-1);

  Future<void> _adjustMapZoom(double delta) async {
    if (!_supportsGoogleMapsPlatform()) {
      _setInlineMessage(
        'Map controls work on Android, iOS, and web builds with Google Maps enabled.',
      );
      return;
    }

    final controller = _mapController;
    if (controller == null) {
      _setInlineMessage(
        'The map is still loading. Try zooming again in a moment.',
      );
      return;
    }

    final nextZoom = (_cameraPosition.zoom + delta)
        .clamp(_minMapZoom, _maxMapZoom)
        .toDouble();
    final nextCameraPosition = CameraPosition(
      target: _cameraPosition.target,
      zoom: nextZoom,
      bearing: _cameraPosition.bearing,
      tilt: _cameraPosition.tilt,
    );

    _cameraPosition = nextCameraPosition;
    _logCameraAction('adjustMapZoom', 'delta=$delta nextZoom=$nextZoom');
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(nextCameraPosition),
    );
    if (!mounted) return;
    setState(() {});
  }

  void _logCameraAction(String action, String details) {
    final keyboardVisible =
        mounted && MediaQuery.viewInsetsOf(context).bottom > 0;
    final focusActive = FocusManager.instance.primaryFocus?.hasFocus == true;
    debugPrint(
      '[MapCamera] action=$action details=$details focusActive=$focusActive keyboardVisible=$keyboardVisible camera=${_cameraPosition.target.latitude.toStringAsFixed(5)},${_cameraPosition.target.longitude.toStringAsFixed(5)} zoom=${_cameraPosition.zoom.toStringAsFixed(2)}',
    );
  }

  bool _shouldApplyAutofill(String currentValue, String? previousAutoValue) {
    final trimmedCurrent = currentValue.trim();
    if (trimmedCurrent.isEmpty) {
      return true;
    }

    final previous = previousAutoValue?.trim() ?? '';
    return previous.isNotEmpty && trimmedCurrent == previous;
  }

  String _formatAddress(Placemark placemark) {
    final parts = <String>[
      placemark.name ?? '',
      placemark.street ?? '',
      placemark.subLocality ?? '',
      placemark.locality ?? '',
      placemark.administrativeArea ?? '',
    ];

    final seen = <String>{};
    return parts
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .where((value) => seen.add(value.toLowerCase()))
        .join(', ');
  }

  String _formatPostcodeOrArea(Placemark placemark) {
    final postcode = placemark.postalCode?.trim() ?? '';
    if (postcode.isNotEmpty) {
      return postcode;
    }

    final locality = placemark.locality?.trim() ?? '';
    if (locality.isNotEmpty) {
      return locality;
    }

    return placemark.administrativeArea?.trim() ?? '';
  }
}

class _VanAddDropHeader extends StatelessWidget {
  const _VanAddDropHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13.2,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
        ),
      ],
    );
  }
}

class _VanAddDropIntroCard extends StatelessWidget {
  const _VanAddDropIntroCard();

  @override
  Widget build(BuildContext context) {
    return _VanAddDropCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF4A7DFF).withValues(alpha: 0.18),
              border: Border.all(
                color: const Color(0xFF4A7DFF).withValues(alpha: 0.28),
              ),
            ),
            child: const Icon(
              Icons.add_location_alt_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pin first',
                  style: TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Search or move the map, then long press the exact entrance or bay.',
                  style: TextStyle(
                    fontSize: 11.9,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VanAddDropCard extends StatelessWidget {
  const _VanAddDropCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _VanMapSearchField extends StatelessWidget {
  const _VanMapSearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      // Keep the picker/map stable; the keyboard should overlay instead of pushing the page.
      scrollPadding: EdgeInsets.zero,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        hintText: 'Search place or postcode',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.52)),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF4A7DFF)),
        ),
      ),
    );
  }
}

class _VanGoogleAutocompleteCard extends StatelessWidget {
  const _VanGoogleAutocompleteCard({
    required this.suggestions,
    required this.isLoading,
    required this.errorText,
    required this.emptyMessage,
    required this.onSuggestionTap,
  });

  final List<PlacesAutocompleteSuggestion> suggestions;
  final bool isLoading;
  final String? errorText;
  final String emptyMessage;
  final ValueChanged<PlacesAutocompleteSuggestion> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final visibleError = errorText?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Search Results',
                style: TextStyle(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select a result, then long press the exact point you want to save.',
            style: TextStyle(
              fontSize: 11.2,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 10),
          if (visibleError != null && visibleError.isNotEmpty)
            Text(
              visibleError,
              style: const TextStyle(
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFFC2BD),
              ),
            )
          else if (!isLoading && suggestions.isEmpty)
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 11.8,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            )
          else
            ...suggestions.take(5).map((suggestion) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => onSuggestionTap(suggestion),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion.primaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (suggestion.secondaryText.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            suggestion.secondaryText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.6,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.70),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _VanAutocompleteResultsSection extends StatelessWidget {
  const _VanAutocompleteResultsSection({
    required this.searchController,
    required this.autocompleteController,
    required this.emptyMessage,
    required this.onSuggestionTap,
  });

  final TextEditingController searchController;
  final PlacesAutocompleteController autocompleteController;
  final String emptyMessage;
  final ValueChanged<PlacesAutocompleteSuggestion> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        searchController,
        autocompleteController,
      ]),
      builder: (context, _) {
        final trimmedQuery = searchController.text.trim();
        final shouldShowCard =
            trimmedQuery.length >= 2 &&
            (autocompleteController.supportsAutocomplete &&
                (autocompleteController.isSearching ||
                    autocompleteController.errorText != null ||
                    autocompleteController.suggestions.isNotEmpty));

        if (!shouldShowCard) {
          return const SizedBox.shrink();
        }

        return _VanGoogleAutocompleteCard(
          suggestions: autocompleteController.suggestions,
          isLoading: autocompleteController.isSearching,
          errorText: autocompleteController.errorText,
          emptyMessage: emptyMessage,
          onSuggestionTap: onSuggestionTap,
        );
      },
    );
  }
}

class _VanMapIconButton extends StatelessWidget {
  const _VanMapIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _VanMapTypeButton extends StatelessWidget {
  const _VanMapTypeButton({required this.mapType, required this.onTap});

  final MapType mapType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSatellite = mapType == MapType.satellite;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSatellite ? Icons.satellite_alt_outlined : Icons.map_outlined,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                isSatellite ? 'Satellite' : 'Map',
                style: const TextStyle(
                  fontSize: 12.6,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VanMapZoomControls extends StatelessWidget {
  const _VanMapZoomControls({required this.onZoomIn, required this.onZoomOut});

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _VanMapIconButton(icon: Icons.add_rounded, onTap: onZoomIn),
        const SizedBox(height: 6),
        _VanMapIconButton(icon: Icons.remove_rounded, onTap: onZoomOut),
      ],
    );
  }
}

class _VanAddDropMapSurface extends StatelessWidget {
  static int _buildCount = 0;

  const _VanAddDropMapSurface({
    required this.cameraPosition,
    required this.mapType,
    required this.myLocationEnabled,
    required this.selectedPinMarkers,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onCameraIdle,
    required this.onLongPress,
  });

  final CameraPosition cameraPosition;
  final MapType mapType;
  final bool myLocationEnabled;
  final Set<Marker> selectedPinMarkers;
  final MapCreatedCallback onMapCreated;
  final ValueChanged<CameraPosition> onCameraMove;
  final VoidCallback onCameraIdle;
  final ValueChanged<LatLng> onLongPress;

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    debugPrint('[Perf] Add Drop map build #$_buildCount');
    if (!_supportsGoogleMapsPlatform()) {
      return Container(
        color: const Color(0xFF0E1726),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Text(
          'The Add Drop map works on Android, iOS, and web builds with Google Maps enabled.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.74),
          ),
        ),
      );
    }

    final gestureRecognizers = <Factory<OneSequenceGestureRecognizer>>{
      Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
    };

    return GoogleMap(
      initialCameraPosition: cameraPosition,
      markers: selectedPinMarkers,
      mapType: mapType,
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      tiltGesturesEnabled: false,
      onMapCreated: onMapCreated,
      onCameraMove: onCameraMove,
      onCameraIdle: onCameraIdle,
      onLongPress: onLongPress,
      gestureRecognizers: gestureRecognizers,
    );
  }
}

class _VanPinStatusBar extends StatelessWidget {
  const _VanPinStatusBar({
    required this.selectedPin,
    required this.isResolving,
  });

  final LatLng? selectedPin;
  final bool isResolving;

  @override
  Widget build(BuildContext context) {
    final hasSelectedPin = selectedPin != null;
    final title = hasSelectedPin ? 'Pin ready' : 'Long press exact pin';
    final subtitle = hasSelectedPin
        ? 'Long press again to adjust the entrance or bay.'
        : 'Search nearby first, then long press the entrance or bay.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.36),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.6,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.8,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.76),
                  ),
                ),
              ],
            ),
          ),
          if (isResolving)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _VanInputField extends StatelessWidget {
  const _VanInputField({
    required this.controller,
    required this.label,
    this.textInputAction,
    this.minLines = 1,
    this.maxLines = 1,
    this.focusNode,
    this.keyboardType,
    this.autofillHints,
    this.enableSuggestions,
    this.autocorrect,
    this.onSubmitted,
    this.onChanged,
    this.scrollController,
    this.scrollTargetKey,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction? textInputAction;
  final int minLines;
  final int maxLines;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool? enableSuggestions;
  final bool? autocorrect;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final ScrollController? scrollController;
  final GlobalKey? scrollTargetKey;

  @override
  Widget build(BuildContext context) {
    final content = TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      // Keep the map and shell static; the keyboard should overlay instead of pushing the page.
      scrollPadding: EdgeInsets.zero,
      autofillHints: autofillHints,
      enableSuggestions: enableSuggestions ?? true,
      autocorrect: autocorrect ?? true,
      onSubmitted: onSubmitted,
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
      ),
    );

    if (scrollTargetKey == null) {
      return content;
    }

    return Container(key: scrollTargetKey, child: content);
  }
}

class _VanTypeField extends StatelessWidget {
  const _VanTypeField({required this.selectedType, required this.onChanged});

  final VanPlaceType selectedType;
  final ValueChanged<VanPlaceType?> onChanged;

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
          .map(
            (type) => DropdownMenuItem<VanPlaceType>(
              value: type,
              child: Text(type.label),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _VanCompactNoteCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;
  final int maxLines;

  const _VanCompactNoteCard({
    required this.label,
    required this.value,
    this.accent,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = accent ?? const Color(0xFF7EA2FF);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: highlight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.2,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
        ],
      ),
    );
  }
}

class _VanCompactStatusCard extends StatelessWidget {
  final String title;
  final String body;
  final Color accent;

  const _VanCompactStatusCard({
    required this.title,
    required this.body,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.2,
              height: 1.32,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.80),
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
