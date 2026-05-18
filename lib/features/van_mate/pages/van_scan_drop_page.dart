import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/van_place.dart';
import '../services/van_premium_service.dart';
import 'van_map_page.dart';
import 'van_premium_page.dart';
import '../services/van_storage_service.dart';

class VanScanDropPageResult {
  const VanScanDropPageResult({
    required this.place,
    required this.addToRoute,
    required this.wasDuplicate,
  });

  final VanPlace place;
  final bool addToRoute;
  final bool wasDuplicate;
}

class VanScanDropPage extends StatefulWidget {
  const VanScanDropPage({
    super.key,
    required this.storage,
    required this.currentUserId,
  });

  final VanStorageService storage;
  final String currentUserId;

  @override
  State<VanScanDropPage> createState() => _VanScanDropPageState();
}

class _VanScanDropPageState extends State<VanScanDropPage> {
  static const String _noTextMessage =
      "Couldn't read the address. Try a clearer photo or enter it manually.";

  static final RegExp _ukPostcodeRegex = RegExp(
    r'\b(GIR\s?0AA|(?:[A-PR-UWYZ][A-HK-Y]?\d[0-9A-HJKSTUW]?\s?\d[ABD-HJLNP-UW-Z]{2}))\b',
    caseSensitive: false,
  );

  static final RegExp _ukPostcodeReviewRegex = RegExp(
    r'\b(?:GIR\s?0AA|(?:[A-PR-UWYZ][A-HK-Y]?\d[0-9A-HJKSTUW]?\s?\d[A-Z0-9]{0,2}))\b',
    caseSensitive: false,
  );

  static final RegExp _ukPostcodeCandidateRegex = RegExp(
    r'\b(?:GIR\s?0AA|(?:[A-PR-UWYZ][A-HK-Y]?\d[0-9A-HJKSTUW]?\s?\d[A-Z0-9]{0,2}))\b',
    caseSensitive: false,
  );

  static final RegExp _ukPostcodeCompactRegex = RegExp(
    r'^(?:GIR0AA|(?:[A-PR-UWYZ][A-HK-Y]?\d[0-9A-HJKSTUW]?\d[ABD-HJLNP-UW-Z]{2}))$',
    caseSensitive: false,
  );

  static final RegExp _addressKeywordRegex = RegExp(
    r'\b(road|rd|street|st|avenue|ave|lane|ln|drive|dr|close|cl|court|ct|'
    r'place|pl|way|park|industrial|unit|warehouse|building|bldg|suite|floor|'
    r'apartment|apt|flat|shop|office|centre|center|yard|estate)\b',
    caseSensitive: false,
  );

  static final RegExp _phoneKeywordRegex = RegExp(
    r'\b(?:tel|telephone|phone|mobile|mob|fax)\b',
    caseSensitive: false,
  );

  static final RegExp _emailRegex = RegExp(
    r'\b[\w.+-]+@[\w.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );

  static final RegExp _webRegex = RegExp(
    r'(?:https?://|www\.)',
    caseSensitive: false,
  );

  final ImagePicker _imagePicker = ImagePicker();
  late final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _postcodeController;
  late final TextEditingController _notesController;

  XFile? _pickedImage;
  String? _statusMessage;
  bool _statusIsError = false;
  bool _isProcessing = false;
  bool _isProcessingOcr = false;
  bool _isApplyingOcrResult = false;
  bool _hasAppliedCurrentOcrResult = false;
  bool _isSaving = false;
  LatLng? _selectedExactPin;
  int _ocrSessionId = 0;
  bool _isPremiumAllowed = false;
  bool _premiumLoaded = false;

  bool get _supportsOcr =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _isActionBusy =>
      _isProcessing || _isProcessingOcr || _isApplyingOcrResult || _isSaving;

  @override
  void initState() {
    super.initState();
    debugPrint('[ScanDropPage] opened');
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _postcodeController = TextEditingController();
    _notesController = TextEditingController();
    VanMatePremiumService.instance.addListener(_handlePremiumChanged);
    unawaited(_loadPremiumStatus());
  }

  @override
  void dispose() {
    VanMatePremiumService.instance.removeListener(_handlePremiumChanged);
    _nameController.dispose();
    _addressController.dispose();
    _postcodeController.dispose();
    _notesController.dispose();
    unawaited(_textRecognizer.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[ScanDropPage] build');
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    if (!_premiumLoaded) {
      return _buildCheckingPremiumScreen(bottomInset);
    }

    if (!_isPremiumAllowed) {
      return _buildLockedScreen(bottomInset);
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF05070C),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _VanScanDropHeaderButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Scan Drop',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Tip: crop only the delivery name, address, and postcode for best results.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Avoid barcodes, tracking numbers, phone numbers, websites, and route labels.',
                style: TextStyle(
                  fontSize: 11.8,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.58),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: _VanScanDropActionButton(
                  label: _isActionBusy ? 'Working...' : 'Take Photo',
                  icon: Icons.photo_camera_outlined,
                  accent: const Color(0xFF4A7DFF),
                  primary: true,
                  busy: _isActionBusy,
                  onTap: (!_supportsOcr || _isActionBusy)
                      ? null
                      : () {
                          debugPrint('[ScanDropPage] Take photo tapped');
                          unawaited(_pickAndRecognize(ImageSource.camera));
                        },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _VanScanDropActionButton(
                  label: _isActionBusy ? 'Working...' : 'Choose Image',
                  icon: Icons.photo_library_outlined,
                  accent: const Color(0xFF67A1FF),
                  primary: false,
                  busy: _isActionBusy,
                  onTap: (!_supportsOcr || _isActionBusy)
                      ? null
                      : () {
                          debugPrint('[ScanDropPage] Choose image tapped');
                          unawaited(_pickAndRecognize(ImageSource.gallery));
                        },
                ),
              ),
              const SizedBox(height: 12),
              _VanScanDropStatusBox(
                message:
                    _statusMessage ??
                    (_supportsOcr
                        ? 'Ready to scan. Take a photo or choose an image to begin.'
                        : 'OCR is available on Android and iPhone builds only.'),
                error: _statusIsError,
              ),
              if (_pickedImage != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Selected image: ${_pickedImage!.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Confirm details',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Edit anything OCR got wrong before you save.',
                      style: TextStyle(
                        fontSize: 12.3,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.66),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Check the postcode and remove any phone numbers before saving.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.54),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _VanScanDropField(
                      label: 'Name / Label',
                      controller: _nameController,
                      hintText: 'Customer, business, or label',
                      maxLines: 1,
                    ),
                    const SizedBox(height: 10),
                    _VanScanDropField(
                      label: 'Address',
                      controller: _addressController,
                      hintText: 'Street, building, unit, or delivery address',
                      minLines: 3,
                      maxLines: 6,
                    ),
                    const SizedBox(height: 10),
                    _VanScanDropField(
                      label: 'Postcode',
                      controller: _postcodeController,
                      hintText: 'UK postcode',
                      textCapitalization: TextCapitalization.characters,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 10),
                    _VanScanDropField(
                      label: 'Extra OCR text / Notes',
                      controller: _notesController,
                      hintText:
                          'Gate code, delivery note, or extra instructions',
                      minLines: 3,
                      maxLines: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedExactPin == null
                          ? 'Optional: set exact pin'
                          : 'Exact pin set',
                      style: const TextStyle(
                        fontSize: 15.6,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedExactPin == null
                          ? 'Set it now for tighter route accuracy, or save from OCR details.'
                          : 'This drop will save with the selected coordinates.',
                      style: TextStyle(
                        fontSize: 12.1,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.66),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _VanScanDropActionButton(
                        label: _selectedExactPin == null
                            ? 'Set exact pin'
                            : 'Edit pin',
                        icon: _selectedExactPin == null
                            ? Icons.pin_drop_outlined
                            : Icons.edit_location_alt_outlined,
                        accent: const Color(0xFF67A1FF),
                        primary: false,
                        busy: _isActionBusy,
                        onTap: _isActionBusy ? null : _openExactPinPicker,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _VanScanDropActionButton(
                  label: _isSaving ? 'Saving...' : 'Add to Route',
                  icon: Icons.route_outlined,
                  accent: const Color(0xFF4A7DFF),
                  primary: true,
                  busy: _isSaving,
                  onTap: _isActionBusy
                      ? null
                      : () {
                          debugPrint('[ScanDropPage] Add to Route tapped');
                          unawaited(_commit(addToRoute: true));
                        },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _VanScanDropActionButton(
                  label: _isSaving ? 'Saving...' : 'Save Place',
                  icon: Icons.bookmark_add_outlined,
                  accent: const Color(0xFF58D0A4),
                  primary: true,
                  busy: _isSaving,
                  onTap: _isActionBusy
                      ? null
                      : () {
                          debugPrint('[ScanDropPage] Save Place tapped');
                          unawaited(_commit(addToRoute: false));
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadPremiumStatus() async {
    final premiumService = VanMatePremiumService.instance;
    await premiumService.ensureLoaded();
    if (!mounted) {
      return;
    }

    setState(() {
      _premiumLoaded = true;
      _isPremiumAllowed = premiumService.canUseScanDrop;
    });
    debugPrint('[ScanDropPage] premium allowed: $_isPremiumAllowed');
  }

  void _handlePremiumChanged() {
    if (!mounted) {
      return;
    }

    final premiumAllowed = VanMatePremiumService.instance.canUseScanDrop;
    if (_premiumLoaded && _isPremiumAllowed == premiumAllowed) {
      return;
    }

    setState(() {
      _premiumLoaded = true;
      _isPremiumAllowed = premiumAllowed;
    });
    debugPrint('[ScanDropPage] premium allowed: $_isPremiumAllowed');
  }

  Widget _buildLockedScreen(double bottomInset) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF05070C),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _VanScanDropHeaderButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Scan Drop is Premium',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan a label, crop the address, and save faster with Premium. Free users can still add drops manually from Places.',
                style: TextStyle(
                  fontSize: 13.1,
                  height: 1.36,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Premium feature',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8EA7FF),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Scan Drop OCR',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan a label, crop address, save fast',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.34,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const VanPremiumPage()),
                    );
                  },
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text('Open Premium'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckingPremiumScreen(double bottomInset) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF05070C),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 20),
          child: const Center(
            child: Text(
              'Checking Premium access...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndRecognize(ImageSource source) async {
    if (_isActionBusy) {
      return;
    }

    if (!_supportsOcr) {
      _setStatus(
        'OCR is available on Android and iPhone builds only.',
        isError: true,
      );
      return;
    }

    final sessionId = ++_ocrSessionId;

    try {
      debugPrint('[ScanDropPage] OCR started');
      if (mounted) {
        setState(() {
          _isProcessing = true;
          _isProcessingOcr = true;
          _hasAppliedCurrentOcrResult = false;
          _isApplyingOcrResult = false;
          _statusMessage = 'Preparing the scan...';
          _statusIsError = false;
        });
      }

      final pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 92,
        requestFullMetadata: false,
      );
      if (!mounted || sessionId != _ocrSessionId) {
        return;
      }
      if (pickedImage == null) {
        _setStatus('Image selection cancelled.', isError: false);
        return;
      }

      if (mounted) {
        setState(() {
          _pickedImage = pickedImage;
          _statusMessage =
              'Crop around the address only. Leave out barcodes, phone numbers, refs and other text.';
          _statusIsError = false;
        });
      }

      debugPrint('[ScanDropPage] Crop started');
      final croppedImage = await _cropForOcr(pickedImage);
      if (!mounted || sessionId != _ocrSessionId) {
        return;
      }
      if (croppedImage == null) {
        _setStatus(
          'Crop cancelled. Pick another photo or enter it manually.',
          isError: false,
        );
        return;
      }

      if (mounted) {
        setState(() {
          _pickedImage = croppedImage;
          _statusMessage = 'Reading the cropped image...';
          _statusIsError = false;
        });
      }

      final inputImage = InputImage.fromFilePath(croppedImage.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      if (!mounted || sessionId != _ocrSessionId) {
        return;
      }

      debugPrint('[ScanDropPage] OCR complete');
      final draft = _parseRecognizedText(recognizedText.text);

      if (draft.rawText.trim().isEmpty) {
        _reportScanIssue(_noTextMessage);
        return;
      }

      if (!mounted || sessionId != _ocrSessionId) {
        return;
      }

      _isApplyingOcrResult = true;
      try {
        if (_hasAppliedCurrentOcrResult) {
          return;
        }

        _applyDraft(draft);
        _hasAppliedCurrentOcrResult = true;
      } finally {
        _isApplyingOcrResult = false;
      }

      debugPrint('[ScanDropPage] Controllers populated');
      _setStatus('Address ready for review.', isError: false);
    } catch (error, stackTrace) {
      debugPrint('[ScanDropPage] OCR failed: $error');
      debugPrint(stackTrace.toString());
      _reportScanIssue(
        'Could not read the scan. Try another crop or enter it manually.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isProcessingOcr = false;
        });
      }
    }
  }

  Future<void> _openExactPinPicker() async {
    if (_isActionBusy) {
      return;
    }

    try {
      final navigator = Navigator.of(context);
      final draftCamera = await _draftCameraPosition();
      if (!mounted) {
        return;
      }
      final result = await navigator.push<VanMapPageResult>(
        MaterialPageRoute<VanMapPageResult>(
          fullscreenDialog: true,
          builder: (_) => VanMapPage(
            places: const <VanPlace>[],
            initialCameraPosition: draftCamera,
            initialSelectedPin: _selectedExactPin,
            selectedPinActionLabel: 'Use Exact Pin',
          ),
        ),
      );

      if (!mounted || result == null) {
        return;
      }

      if (result.useSelectedPin && result.selectedPin != null) {
        setState(() {
          _selectedExactPin = result.selectedPin;
        });
        _setStatus(
          'Exact pin set. You can save this drop now.',
          isError: false,
        );
        return;
      }

      _setStatus(
        'Pin not set. You can still save from the OCR details.',
        isError: false,
      );
    } catch (_) {
      _reportScanIssue(
        'Could not open the map picker. You can still save from the OCR details.',
      );
    }
  }

  Future<CameraPosition?> _draftCameraPosition() async {
    if (_selectedExactPin != null) {
      return CameraPosition(target: _selectedExactPin!, zoom: 15.2);
    }

    final coordinates = await _resolveCoordinates(
      name: _resolvedName(),
      address: _addressController.text.trim(),
      postcode: _normalizeUkPostcode(_postcodeController.text.trim()),
    );

    if (!mounted) {
      return null;
    }

    if (coordinates == null) {
      return null;
    }

    return CameraPosition(
      target: LatLng(coordinates.latitude, coordinates.longitude),
      zoom: 15.2,
    );
  }

  Future<XFile?> _cropForOcr(XFile image) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      compressQuality: 96,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop around the address only',
          toolbarColor: const Color(0xFF101826),
          toolbarWidgetColor: Colors.white,
          backgroundColor: const Color(0xFF05070C),
          activeControlsWidgetColor: const Color(0xFF4A7DFF),
          dimmedLayerColor: Colors.black.withValues(alpha: 0.65),
          cropFrameColor: Colors.white,
          cropGridColor: Colors.white.withValues(alpha: 0.24),
          showCropGrid: true,
          hideBottomControls: false,
          lockAspectRatio: false,
          initAspectRatio: CropAspectRatioPreset.original,
          cropStyle: CropStyle.rectangle,
          aspectRatioPresets: const [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'Crop around the address only',
          aspectRatioPresets: const [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
          rotateClockwiseButtonHidden: false,
          rotateButtonsHidden: false,
          resetButtonHidden: false,
          aspectRatioPickerButtonHidden: false,
        ),
      ],
    );

    if (croppedFile == null) {
      return null;
    }

    debugPrint('[ScanDropPage] Crop complete');
    return XFile(croppedFile.path, name: image.name, mimeType: image.mimeType);
  }

  void _applyDraft(_VanScanDropDraft draft) {
    _setControllerText(_nameController, draft.name);
    _setControllerText(_addressController, draft.address);
    _setControllerText(_postcodeController, draft.postcode);
    _setControllerText(_notesController, draft.notes);
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }

    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _reportScanIssue(String message) {
    _setStatus(message, isError: true);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB24C4C),
      ),
    );
  }

  void _setStatus(String message, {required bool isError}) {
    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<void> _commit({required bool addToRoute}) async {
    if (_isActionBusy) {
      return;
    }

    final ownerId = widget.currentUserId.trim();
    if (ownerId.isEmpty) {
      _setStatus(
        'Van Mate needs a signed-in account before drops can save.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      debugPrint(
        addToRoute
            ? '[ScanDropPage] Add to Route tapped'
            : '[ScanDropPage] Save Place tapped',
      );
      final draft = await _buildPlaceDraft(ownerId);
      if (!mounted) {
        return;
      }
      final saveResult = await widget.storage.savePlace(
        draft,
        checkForDuplicate: true,
      );
      if (!mounted) {
        return;
      }
      final place = saveResult.place ?? saveResult.duplicatePlace ?? draft;
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        VanScanDropPageResult(
          place: place,
          addToRoute: addToRoute,
          wasDuplicate:
              saveResult.type == VanSavePlaceResultType.duplicateSuggested,
        ),
      );
    } catch (_) {
      _reportScanIssue(
        'Drop save failed in Firebase. Check the connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<VanPlace> _buildPlaceDraft(String ownerId) async {
    final now = DateTime.now();
    final name = _resolvedName();
    final address = _addressController.text.trim();
    final postcode = _normalizeUkPostcode(_postcodeController.text.trim());
    final notes = _notesController.text.trim();
    final coordinates = _selectedExactPin != null
        ? _VanScanDropLocation(
            latitude: _selectedExactPin!.latitude,
            longitude: _selectedExactPin!.longitude,
          )
        : await _resolveCoordinates(
            name: name,
            address: address,
            postcode: postcode,
          );

    return VanPlace(
      id: widget.storage.createPlaceId(),
      ownerId: ownerId,
      name: name,
      address: address,
      postcodeArea: postcode,
      deliveryNote: notes,
      warningNote: '',
      privateInfo: '',
      placeType: VanPlaceType.other,
      latitude: coordinates?.latitude,
      longitude: coordinates?.longitude,
      createdAt: now,
      updatedAt: now,
      createdBy: ownerId,
    );
  }

  String _resolvedName() {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isNotEmpty) {
      return trimmedName;
    }

    final address = _addressController.text.trim();
    if (address.isNotEmpty) {
      final firstAddressLine = address
          .split(RegExp(r'[\r\n,]+'))
          .map((line) => line.trim())
          .firstWhere((line) => line.isNotEmpty, orElse: () => '');
      if (firstAddressLine.isNotEmpty) {
        return firstAddressLine;
      }
    }

    final postcode = _normalizeUkPostcode(_postcodeController.text.trim());
    if (postcode.isNotEmpty) {
      return postcode;
    }

    return 'Scanned Drop';
  }

  Future<_VanScanDropLocation?> _resolveCoordinates({
    required String name,
    required String address,
    required String postcode,
  }) async {
    final queries = <String>[
      _composeGeocodeQuery(name: name, address: address, postcode: postcode),
      if (postcode.isNotEmpty) postcode,
      if (address.isNotEmpty) address,
      if (name.isNotEmpty && address.isNotEmpty) '$name, $address',
    ];

    for (final query in queries) {
      final normalizedQuery = query.trim();
      if (normalizedQuery.isEmpty) {
        continue;
      }

      try {
        final locations = await locationFromAddress(normalizedQuery);
        if (locations.isNotEmpty) {
          final location = locations.first;
          return _VanScanDropLocation(
            latitude: location.latitude,
            longitude: location.longitude,
          );
        }
      } catch (_) {}
    }

    return null;
  }

  String _composeGeocodeQuery({
    required String name,
    required String address,
    required String postcode,
  }) {
    final parts = <String>[
      name.trim(),
      address.trim().replaceAll(RegExp(r'[\r\n]+'), ', '),
      postcode.trim(),
      'UK',
    ];

    return parts.where((part) => part.isNotEmpty).join(', ');
  }

  _VanScanDropDraft _parseRecognizedText(String rawText) {
    final parsed = _parseRecognizedLines(rawText);
    _logParsedText(parsed);

    return _VanScanDropDraft(
      rawText: parsed.rawText,
      name: parsed.name,
      address: parsed.addressLines.join('\n').trim(),
      postcode: parsed.postcode,
      notes: parsed.noteLines.join('\n').trim(),
    );
  }

  String _normalizeUkPostcode(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (compact.isEmpty) {
      return '';
    }

    if (_isValidUkPostcodeCompact(compact)) {
      return '${compact.substring(0, compact.length - 3)} ${compact.substring(compact.length - 3)}';
    }

    return _formatUkPostcodeReviewCompact(compact);
  }

  _VanScanDropParsedText _parseRecognizedLines(String rawText) {
    final rawLines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map(_cleanRecognizedLine)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final rejectedLines = <String>[];
    final processedLines = <_VanScanDropLineData>[];

    for (var index = 0; index < rawLines.length; index++) {
      final rawLine = rawLines[index];
      final strippedLine = _stripKnownHeaderPrefix(rawLine);
      if (strippedLine.isEmpty) {
        rejectedLines.add(rawLine);
        continue;
      }

      if (_looksLikePhoneLine(rawLine) || _looksLikePhoneLine(strippedLine)) {
        rejectedLines.add(rawLine);
        continue;
      }

      if (_looksLikeHardJunkLine(strippedLine) || _looksLikeHardJunkLine(rawLine)) {
        rejectedLines.add(rawLine);
        continue;
      }

      final extractedPostcode = _extractUkPostcode(strippedLine);
      final cleanedLine = _normalizeRecognizedLine(
        extractedPostcode.cleanedLine,
      );
      final usableLine = cleanedLine.isNotEmpty ? cleanedLine : strippedLine;

      if (usableLine.isEmpty && extractedPostcode.postcode.isEmpty) {
        continue;
      }

      if (_looksLikeLabelOnlyLine(usableLine) ||
          _looksLikePhoneLine(usableLine)) {
        rejectedLines.add(rawLine);
        continue;
      }

      if (processedLines.isNotEmpty &&
          processedLines.last.usableLine.toLowerCase() ==
              usableLine.toLowerCase() &&
          processedLines.last.postcode.toLowerCase() ==
              extractedPostcode.postcode.toLowerCase()) {
        continue;
      }

      processedLines.add(
        _VanScanDropLineData(
          sourceIndex: index,
          rawLine: rawLine,
          cleanedLine: cleanedLine,
          usableLine: usableLine,
          postcode: extractedPostcode.postcode,
          isPostcodeCandidate: extractedPostcode.isCandidate,
        ),
      );
    }

    final postcodeIndex = _findPostcodeLineIndex(processedLines);
    final selectedPostcode = postcodeIndex >= 0
        ? processedLines[postcodeIndex].postcode
        : '';

    final nameIndex = _chooseNameIndex(processedLines, postcodeIndex);
    String name = '';
    if (nameIndex >= 0 && nameIndex < processedLines.length) {
      name = processedLines[nameIndex].usableLine;
    }

    final addressLines = <String>[];
    final noteLines = <String>[];

    for (var i = 0; i < processedLines.length; i++) {
      final line = processedLines[i];
      final text = line.usableLine;

      if (i == nameIndex) {
        continue;
      }

      if (name.isNotEmpty && _sameNormalizedText(text, name)) {
        continue;
      }

      if (line.postcode.isNotEmpty && i == postcodeIndex) {
        final cleanedPostcodeLine = _normalizeRecognizedLine(line.cleanedLine);
        if (cleanedPostcodeLine.isNotEmpty) {
          addressLines.add(cleanedPostcodeLine);
        }
        continue;
      }

      if (text.isEmpty) {
        continue;
      }

      if (postcodeIndex >= 0 && i > postcodeIndex) {
        if (_looksLikeUsefulNoteLine(text)) {
          noteLines.add(text);
        } else {
          rejectedLines.add(text);
        }
        continue;
      }

      addressLines.add(text);
    }

    if (addressLines.isEmpty) {
      for (var i = 0; i < processedLines.length; i++) {
        if (i == nameIndex) {
          continue;
        }
        final line = processedLines[i].usableLine;
        if (line.isEmpty ||
            _looksLikeHardJunkLine(line) ||
            (name.isNotEmpty && _sameNormalizedText(line, name))) {
          continue;
        }
        addressLines.add(line);
      }
    }

    if (addressLines.isEmpty && processedLines.isNotEmpty) {
      addressLines.addAll(
        processedLines
            .map((line) => line.usableLine)
            .where((line) => line.isNotEmpty),
      );
    }

    if (noteLines.isEmpty) {
      for (var i = 0; i < processedLines.length; i++) {
        final line = processedLines[i].usableLine;
        if (line.isEmpty ||
            i == nameIndex ||
            addressLines.contains(line) ||
            (name.isNotEmpty && _sameNormalizedText(line, name))) {
          continue;
        }
        if (!_looksLikeHardJunkLine(line)) {
          noteLines.add(line);
        }
      }
    }

    final expandedAddressLines = _expandCommaSeparatedAddressLines(
      addressLines,
    );
    final dedupedAddressLines = _cleanDuplicatePostcodeLines(
      _dedupeSequentialLines(expandedAddressLines),
      selectedPostcode,
    );
    final dedupedNoteLines = _cleanDuplicatePostcodeLines(
      _dedupeSequentialLines(noteLines),
      selectedPostcode,
    );
    final finalName = name.trim();

    return _VanScanDropParsedText(
      rawText: rawText.trim(),
      rawLines: rawLines,
      cleanedLines: processedLines
          .map((line) => line.usableLine)
          .where((line) => line.isNotEmpty)
          .toList(growable: false),
      rejectedLines: rejectedLines,
      name: finalName,
      addressLines: dedupedAddressLines,
      postcode: selectedPostcode,
      noteLines: dedupedNoteLines,
    );
  }

  _ExtractedPostcode _extractUkPostcode(String line) {
    final normalizedLine = _normalizeRecognizedLine(line);
    if (normalizedLine.isEmpty) {
      return const _ExtractedPostcode(
        cleanedLine: '',
        postcode: '',
        isCandidate: false,
      );
    }

    final tokens = normalizedLine
        .split(RegExp(r'[\s,;:/\\|()\-]+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    final maxWindowSize = tokens.length < 4 ? tokens.length : 4;

    for (var windowSize = 1; windowSize <= maxWindowSize; windowSize++) {
      final candidateText = tokens.sublist(tokens.length - windowSize).join(' ');
      final postcode = _matchUkPostcodeCandidate(
        candidateText,
        allowReview: false,
      );
      if (postcode != null) {
        final cleanedLine = _removeMatchedSubstring(normalizedLine, candidateText);
        return _ExtractedPostcode(
          cleanedLine: cleanedLine.isEmpty ? '' : cleanedLine,
          postcode: postcode,
          isCandidate: false,
        );
      }
    }

    for (var windowSize = 1; windowSize <= maxWindowSize; windowSize++) {
      final candidateText = tokens.sublist(tokens.length - windowSize).join(' ');
      final postcode = _matchUkPostcodeCandidate(
        candidateText,
        allowReview: true,
      );
      if (postcode != null) {
        final cleanedLine = _removeMatchedSubstring(normalizedLine, candidateText);
        return _ExtractedPostcode(
          cleanedLine: cleanedLine.isEmpty ? '' : cleanedLine,
          postcode: postcode,
          isCandidate: true,
        );
      }
    }

    return const _ExtractedPostcode(
      cleanedLine: '',
      postcode: '',
      isCandidate: false,
    );
  }

  String _cleanRecognizedLine(String line) {
    return line
        .replaceAll(RegExp(r'[\u2022\u2023\u25E6\u2043\u2219•·]+'), ' ')
        .replaceAll(RegExp(r'[\t ]+'), ' ')
        .replaceAll(RegExp(r'^[\s\-–—_:;|/]+'), '')
        .trim();
  }

  String _normalizeRecognizedLine(String line) {
    return line.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _cleanDuplicatePostcodeLines(
    List<String> lines,
    String postcode,
  ) {
    if (postcode.trim().isEmpty) {
      return lines;
    }

    final cleanedLines = <String>[];
    for (final line in lines) {
      final cleanedLine = _removeDuplicatePostcodeFromText(line, postcode);
      if (cleanedLine.isEmpty) {
        continue;
      }
      cleanedLines.add(cleanedLine);
    }

    return _dedupeSequentialLines(cleanedLines);
  }

  String _removeDuplicatePostcodeFromText(String text, String postcode) {
    final normalizedText = _normalizeRecognizedLine(text);
    final normalizedPostcode = _normalizeRecognizedLine(postcode).toUpperCase();
    if (normalizedText.isEmpty || normalizedPostcode.isEmpty) {
      return normalizedText;
    }

    final compactPostcode = normalizedPostcode.replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    if (compactPostcode.isEmpty) {
      return normalizedText;
    }

    final postcodePattern = RegExp(
      r'(?<![A-Z0-9])' +
          compactPostcode.split('').map(RegExp.escape).join(r'[\s\-]*') +
          r'(?![A-Z0-9])',
      caseSensitive: false,
    );

    final cleaned = normalizedText.replaceAll(postcodePattern, ' ');
    return cleaned
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s+([,.;:!?])'), r'$1')
        .trim();
  }

  int _findPostcodeLineIndex(List<_VanScanDropLineData> lines) {
    var exactIndex = -1;
    var candidateIndex = -1;

    for (var index = 0; index < lines.length; index++) {
      final postcode = lines[index].postcode;
      if (postcode.isEmpty) {
        continue;
      }

      if (lines[index].isPostcodeCandidate) {
        candidateIndex = index;
      } else {
        exactIndex = index;
      }
    }

    return exactIndex >= 0 ? exactIndex : candidateIndex;
  }

  int _chooseNameIndex(List<_VanScanDropLineData> lines, int postcodeIndex) {
    final end = postcodeIndex >= 0 ? postcodeIndex : lines.length;
    for (var index = 0; index < end; index++) {
      final line = lines[index].usableLine;
      if (line.isEmpty || lines[index].postcode.isNotEmpty) {
        continue;
      }

      if (_looksLikePotentialName(line)) {
        return index;
      }
    }
    return -1;
  }

  bool _looksLikePotentialName(String line) {
    final normalized = _normalizeRecognizedLine(line);
    if (normalized.isEmpty || _looksLikeHardJunkLine(normalized)) {
      return false;
    }

    if (_looksLikeShortCodeLine(normalized)) {
      return false;
    }

    if (RegExp(r'^\d').hasMatch(normalized)) {
      return false;
    }

    if (_addressKeywordRegex.hasMatch(normalized)) {
      return false;
    }

    if (_looksLikePhoneLine(normalized)) {
      return false;
    }

    return normalized.length <= 70;
  }

  bool _isValidUkPostcodeCompact(String compact) {
    return _ukPostcodeCompactRegex.hasMatch(compact);
  }

  String _removeMatchedSubstring(String text, String matchedText) {
    final normalizedText = _normalizeRecognizedLine(text);
    final normalizedMatch = _normalizeRecognizedLine(matchedText);
    if (normalizedText.isEmpty || normalizedMatch.isEmpty) {
      return normalizedText;
    }

    final index = normalizedText.toLowerCase().lastIndexOf(
      normalizedMatch.toLowerCase(),
    );
    if (index < 0) {
      return normalizedText;
    }

    final before = normalizedText.substring(0, index).trim();
    final after = normalizedText.substring(index + normalizedMatch.length).trim();
    return <String>[
      before,
      after,
    ].where((part) => part.isNotEmpty).join(' ').trim();
  }

  bool _looksLikeHardJunkLine(String line) {
    final normalized = _normalizeRecognizedLine(line);
    if (normalized.isEmpty) {
      return true;
    }

    final lower = normalized.toLowerCase();
    if (_looksLikeLabelOnlyLine(normalized)) {
      return true;
    }

    if (_looksLikePhoneLine(normalized)) {
      return true;
    }

    if (_webRegex.hasMatch(normalized) || _emailRegex.hasMatch(normalized)) {
      return true;
    }

    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return true;
    }

    final compact = normalized.replaceAll(RegExp(r'[\s\-_/]+'), '');
    final letters = RegExp(r'[a-zA-Z]').allMatches(compact).length;
    final digits = RegExp(r'\d').allMatches(compact).length;
    final punctuation = RegExp(r'[^a-zA-Z0-9]').allMatches(compact).length;

    if (compact.length <= 4 &&
        RegExp(
          r'^[A-Z]\d{1,3}[A-Z]?$',
          caseSensitive: false,
        ).hasMatch(compact)) {
      return true;
    }

    if (compact.length <= 4 &&
        RegExp(r'^[A-Z0-9]{2,4}$', caseSensitive: false).hasMatch(compact) &&
        !RegExp(r'^\d+$').hasMatch(compact)) {
      return true;
    }

    if (compact.length >= 6 &&
        digits >= 3 &&
        letters <= 3 &&
        !normalized.contains(' ')) {
      return true;
    }

    if (compact.length >= 8 && punctuation >= 2 && letters < 3 && digits >= 2) {
      return true;
    }

    if (normalized.length <= 2) {
      return true;
    }

    if (digits + punctuation > letters * 2 &&
        normalized.length <= 12 &&
        !normalized.contains(' ')) {
      return true;
    }

    if (compact.length >= 12 &&
        digits >= 5 &&
        letters <= 4 &&
        !normalized.contains(' ')) {
      return true;
    }

    return false;
  }

  bool _looksLikeLabelOnlyLine(String line) {
    final normalized = _normalizeRecognizedLine(line).toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    const labelPhrases = <String>[
      'registered office',
      'delivery address',
      'deliver to',
      'ship to',
      'address',
      'customer',
      'account',
      'invoice',
      'tel',
      'telephone',
      'phone',
      'mobile',
      'website',
      'www',
      'email',
      'fca',
      'vat',
      'company number',
      'tracking',
      'barcode',
      'ref',
      'route',
      'parcel',
      'consignment',
      'return address',
      'customer reference',
      'customer ref',
      'department reference',
      'department ref',
      'tracking reference',
      'tracking no',
      'tracking number',
      'reference',
      'ref',
      'barcode',
      'qr code',
      'photo only',
      'no signature',
      'delivery note',
      'address label',
      'parcel label',
      'ship to',
      'bill to',
    ];

    for (final phrase in labelPhrases) {
      if (normalized == phrase || normalized.startsWith('$phrase:')) {
        return true;
      }
    }

    if (normalized.contains('return address')) {
      return true;
    }

    if (normalized.contains('customer reference') ||
        normalized.contains('department reference') ||
        normalized.contains('tracking reference') ||
        normalized.contains('tracking number') ||
        normalized.contains('company number') ||
        normalized.contains('parcel') ||
        normalized.contains('consignment') ||
        normalized.contains('vat') ||
        normalized.contains('fca') ||
        normalized.contains('photo only') ||
        normalized.contains('no signature') ||
        normalized.contains('qr code') ||
        normalized.contains('barcode')) {
      return true;
    }

    return false;
  }

  bool _looksLikeShortCodeLine(String line) {
    final normalized = _normalizeRecognizedLine(line);
    if (normalized.isEmpty) {
      return false;
    }

    if (normalized.length <= 4 &&
        RegExp(r'^[A-Z0-9]{2,4}$').hasMatch(normalized)) {
      return true;
    }

    return RegExp(
      r'^[A-Z]\d{1,3}[A-Z]?$',
      caseSensitive: false,
    ).hasMatch(normalized);
  }

  bool _looksLikeUsefulNoteLine(String line) {
    final normalized = _normalizeRecognizedLine(line);
    if (normalized.isEmpty) {
      return false;
    }

    if (_looksLikeHardJunkLine(normalized) ||
        _ukPostcodeRegex.hasMatch(normalized) ||
        _ukPostcodeCandidateRegex.hasMatch(normalized) ||
        _addressKeywordRegex.hasMatch(normalized)) {
      return false;
    }

    return true;
  }

  String _stripKnownHeaderPrefix(String line) {
    final normalized = _normalizeRecognizedLine(line);
    if (normalized.isEmpty) {
      return '';
    }

    final lower = normalized.toLowerCase();
    const prefixes = <String>[
      'registered office',
      'delivery address',
      'deliver to',
      'ship to',
      'address',
      'customer',
      'account',
      'invoice',
      'tel',
      'telephone',
      'phone',
      'mobile',
      'website',
      'email',
      'fca',
      'vat',
      'company number',
      'tracking',
      'barcode',
      'ref',
      'route',
      'parcel',
      'consignment',
    ];

    for (final prefix in prefixes) {
      if (lower == prefix) {
        return '';
      }

      if (!lower.startsWith(prefix)) {
        continue;
      }

      final nextIndex = prefix.length;
      if (nextIndex >= normalized.length) {
        return '';
      }

      final nextChar = normalized[nextIndex];
      if (' :;|/\\-–—'.contains(nextChar)) {
        return normalized
            .substring(nextIndex)
            .replaceFirst(RegExp(r'^[\s:;|/\\\-–—]+'), '')
            .trim();
      }
    }

    return normalized;
  }

  bool _looksLikePhoneLine(String line) {
    final normalized = _normalizeRecognizedLine(line);
    if (normalized.isEmpty) {
      return false;
    }

    if (_phoneKeywordRegex.hasMatch(normalized)) {
      return true;
    }

    if (_webRegex.hasMatch(normalized) || _emailRegex.hasMatch(normalized)) {
      return false;
    }

    final compact = normalized.replaceAll(RegExp(r'[^0-9+]'), '');
    final digitCount = RegExp(r'\d').allMatches(normalized).length;
    if (digitCount < 7) {
      return false;
    }

    if (RegExp(
      r'^(?:\+?44|0)(?:\d[\s-]?){8,13}\d$',
    ).hasMatch(normalized.replaceAll(RegExp(r'\s+'), ' '))) {
      return true;
    }

    if (RegExp(
      r'^0(?:7\d{8,9}|1\d{8,9}|2\d{8,9}|3\d{8,9}|8\d{8,9})$',
    ).hasMatch(compact)) {
      return true;
    }

    if (RegExp(r'^\+?44\d{9,10}$').hasMatch(compact)) {
      return true;
    }

    return RegExp(r'^\d{7,12}$').hasMatch(compact);
  }

  String? _matchUkPostcodeCandidate(
    String candidateText, {
    required bool allowReview,
  }) {
    final normalized = _normalizeRecognizedLine(candidateText).toUpperCase();
    if (normalized.isEmpty) {
      return null;
    }

    final compact = normalized.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.isEmpty) {
      return null;
    }

    for (final variant in _postcodeCompactVariants(compact)) {
      if (_isValidUkPostcodeCompact(variant)) {
        return _normalizeUkPostcode(variant);
      }
    }

    if (!allowReview) {
      return null;
    }

    final reviewMatch = _ukPostcodeReviewRegex.firstMatch(normalized);
    if (reviewMatch != null) {
      final reviewText = _normalizeRecognizedLine(reviewMatch.group(0) ?? '');
      final reviewCompact = reviewText.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      return _formatUkPostcodeReviewCompact(reviewCompact);
    }

    if (_ukPostcodeCandidateRegex.hasMatch(compact)) {
      return _formatUkPostcodeReviewCompact(compact);
    }

    return null;
  }

  List<String> _postcodeCompactVariants(String compact) {
    final normalized = compact.toUpperCase();
    var variants = <String>[''];

    for (var index = 0; index < normalized.length; index++) {
      final char = normalized[index];
      final options = _postcodeReplacementOptions(char);
      final nextVariants = <String>[];

      for (final prefix in variants) {
        for (final replacement in options) {
          nextVariants.add('$prefix$replacement');
        }
      }

      variants = nextVariants;
      if (variants.length > 256) {
        break;
      }
    }

    return variants.toSet().toList(growable: false);
  }

  List<String> _postcodeReplacementOptions(String char) {
    switch (char.toUpperCase()) {
      case 'O':
        return const ['O', '0'];
      case 'I':
      case 'L':
        return const ['I', '1', 'L'];
      case 'S':
        return const ['S', '5'];
      case 'B':
        return const ['B', '8'];
      default:
        return <String>[char.toUpperCase()];
    }
  }

  String _formatUkPostcodeReviewCompact(String compact) {
    final normalized = compact.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
    if (normalized.isEmpty) {
      return '';
    }

    if (_isValidUkPostcodeCompact(normalized)) {
      return _normalizeUkPostcode(normalized);
    }

    final outwardLength = _inferUkPostcodeOutwardLength(normalized);
    if (outwardLength <= 0 || outwardLength >= normalized.length) {
      return normalized;
    }

    return '${normalized.substring(0, outwardLength)} ${normalized.substring(outwardLength)}';
  }

  int _inferUkPostcodeOutwardLength(String compact) {
    if (compact.length < 5) {
      return 0;
    }

    if (RegExp(r'^[A-Z]\d[A-Z]').hasMatch(compact)) {
      return 3;
    }

    if (RegExp(r'^[A-Z]{2}\d[A-Z]').hasMatch(compact)) {
      return 4;
    }

    if (RegExp(r'^[A-Z]{2}\d').hasMatch(compact)) {
      return 3;
    }

    if (RegExp(r'^[A-Z]\d').hasMatch(compact)) {
      return 2;
    }

    if (RegExp(r'^[A-Z]').hasMatch(compact)) {
      return 3;
    }

    return 0;
  }

  List<String> _dedupeSequentialLines(List<String> lines) {
    final deduped = <String>[];
    for (final line in lines) {
      final normalized = _normalizeRecognizedLine(line);
      if (normalized.isEmpty) {
        continue;
      }

      if (deduped.isNotEmpty &&
          deduped.last.toLowerCase() == normalized.toLowerCase()) {
        continue;
      }

      deduped.add(normalized);
    }

    return deduped;
  }

  List<String> _expandCommaSeparatedAddressLines(List<String> lines) {
    final expanded = <String>[];
    for (final line in lines) {
      final normalized = _normalizeRecognizedLine(line);
      if (normalized.isEmpty) {
        continue;
      }

      final parts = normalized
          .split(',')
          .map(_normalizeRecognizedLine)
          .where((part) => part.isNotEmpty)
          .toList(growable: false);

      if (parts.length >= 2 && normalized.length <= 140) {
        expanded.addAll(parts);
        continue;
      }

      expanded.add(normalized);
    }

    return expanded;
  }

  bool _sameNormalizedText(String first, String second) {
    return _normalizeRecognizedLine(first).toLowerCase() ==
        _normalizeRecognizedLine(second).toLowerCase();
  }

  void _logParsedText(_VanScanDropParsedText parsed) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      '[ScanDrop] raw=${_joinLogLines(parsed.rawLines)} | '
      'kept=${_joinLogLines(parsed.cleanedLines)} | '
      'rejected=${_joinLogLines(parsed.rejectedLines)} | '
      'name="${parsed.name}" | '
      'address=${_joinLogLines(parsed.addressLines)} | '
      'postcode="${parsed.postcode}" | '
      'notes=${_joinLogLines(parsed.noteLines)}',
    );
  }

  String _joinLogLines(List<String> lines) {
    if (lines.isEmpty) {
      return '-';
    }

    final limited = lines.take(6).toList(growable: false);
    return limited.join(' | ');
  }
}

class _VanScanDropDraft {
  const _VanScanDropDraft({
    required this.rawText,
    required this.name,
    required this.address,
    required this.postcode,
    required this.notes,
  });

  final String rawText;
  final String name;
  final String address;
  final String postcode;
  final String notes;
}

class _VanScanDropParsedText {
  const _VanScanDropParsedText({
    required this.rawText,
    required this.rawLines,
    required this.cleanedLines,
    required this.rejectedLines,
    required this.name,
    required this.addressLines,
    required this.postcode,
    required this.noteLines,
  });

  final String rawText;
  final List<String> rawLines;
  final List<String> cleanedLines;
  final List<String> rejectedLines;
  final String name;
  final List<String> addressLines;
  final String postcode;
  final List<String> noteLines;
}

class _VanScanDropLineData {
  const _VanScanDropLineData({
    required this.sourceIndex,
    required this.rawLine,
    required this.cleanedLine,
    required this.usableLine,
    required this.postcode,
    required this.isPostcodeCandidate,
  });

  final int sourceIndex;
  final String rawLine;
  final String cleanedLine;
  final String usableLine;
  final String postcode;
  final bool isPostcodeCandidate;
}

class _ExtractedPostcode {
  const _ExtractedPostcode({
    required this.cleanedLine,
    required this.postcode,
    required this.isCandidate,
  });

  final String cleanedLine;
  final String postcode;
  final bool isCandidate;
}

class _VanScanDropLocation {
  const _VanScanDropLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class _VanScanDropField extends StatelessWidget {
  const _VanScanDropField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.minLines = 1,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final int minLines;
  final int maxLines;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final isMultiLine = maxLines > 1;
    final effectiveMinLines = isMultiLine ? minLines : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.6,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: Colors.white.withValues(alpha: 0.76),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            minLines: effectiveMinLines,
            expands: false,
            textAlignVertical: isMultiLine ? TextAlignVertical.top : null,
            textCapitalization: textCapitalization,
            style: const TextStyle(
              fontSize: 14.1,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                vertical: isMultiLine ? 12 : 12,
              ),
              hintText: hintText,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VanScanDropActionButton extends StatelessWidget {
  const _VanScanDropActionButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.primary,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool primary;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: primary
              ? accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: primary
                ? accent.withValues(alpha: 0.32)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy) ...[
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2.1,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ] else ...[
              Icon(icon, size: 16, color: Colors.white),
            ],
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VanScanDropStatusBox extends StatelessWidget {
  const _VanScanDropStatusBox({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final accent = error ? const Color(0xFFFF8A72) : const Color(0xFF58D0A4);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12.3,
          height: 1.32,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

class _VanScanDropHeaderButton extends StatelessWidget {
  const _VanScanDropHeaderButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }
}
