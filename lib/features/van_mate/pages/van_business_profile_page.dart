import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_business_logo_support.dart';
import '../models/van_business_profile_settings.dart';
import '../services/van_business_logo_storage_service.dart';
import '../services/van_business_profile_storage.dart';
import '../services/van_firebase_auth_service.dart';
import '../widgets/van_back_business_hub_buttons.dart';
import '../widgets/van_form_field_styles.dart';

Future<void> openVanBusinessProfilePage(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const VanBusinessProfilePage()),
  );
}

class VanBusinessProfilePage extends StatefulWidget {
  const VanBusinessProfilePage({super.key});

  @override
  State<VanBusinessProfilePage> createState() => _VanBusinessProfilePageState();
}

class _VanBusinessProfilePageState extends State<VanBusinessProfilePage> {
  final VanBusinessProfileStorage _storage = VanBusinessProfileStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _businessTypeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _addressLine2Controller = TextEditingController();
  final TextEditingController _townController = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _sortCodeController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _paymentNotesController = TextEditingController();
  final TextEditingController _vatNumberController = TextEditingController();
  final TextEditingController _defaultInvoiceNotesController =
      TextEditingController();
  final TextEditingController _defaultPaymentTermsController =
      TextEditingController();
  final TextEditingController _thankYouMessageController =
      TextEditingController();
  final TextEditingController _defaultExtraHelperAmountController =
      TextEditingController();
  final TextEditingController _defaultStairsAccessAmountController =
      TextEditingController();
  final TextEditingController _defaultWaitingTimeAmountController =
      TextEditingController();
  final TextEditingController _defaultCollectionDeliveryAmountController =
      TextEditingController();
  final TextEditingController _defaultMileageRateController =
      TextEditingController();

  bool _vatRegistered = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _logoPath;
  String? _logoUrl;
  String? _logoStoragePath;
  XFile? _selectedLogoUpload;
  String? _logoName;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _businessTypeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _townController.dispose();
    _postcodeController.dispose();
    _bankNameController.dispose();
    _accountNameController.dispose();
    _sortCodeController.dispose();
    _accountNumberController.dispose();
    _paymentNotesController.dispose();
    _vatNumberController.dispose();
    _defaultInvoiceNotesController.dispose();
    _defaultPaymentTermsController.dispose();
    _thankYouMessageController.dispose();
    _defaultExtraHelperAmountController.dispose();
    _defaultStairsAccessAmountController.dispose();
    _defaultWaitingTimeAmountController.dispose();
    _defaultCollectionDeliveryAmountController.dispose();
    _defaultMileageRateController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _storage.loadCanonicalProfile();
      final settings = await _storage.loadSettings();
      if (!mounted) {
        return;
      }

      _applyProfile(
        settings,
        logoUrl: profile.logoUrl,
        logoStoragePath: profile.logoPath,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyProfile(
    VanBusinessProfileSettings profile, {
    String? logoUrl,
    String? logoStoragePath,
  }) {
    setState(() {
      _businessNameController.text = profile.businessName;
      _ownerNameController.text = profile.ownerName;
      _businessTypeController.text = profile.businessType;
      _phoneController.text = profile.phoneNumber;
      _emailController.text = profile.emailAddress;
      _websiteController.text = profile.websiteOrSocialLink;
      _addressLine1Controller.text = profile.addressLine1;
      _addressLine2Controller.text = profile.addressLine2;
      _townController.text = profile.townOrCity;
      _postcodeController.text = profile.postcode;
      _bankNameController.text = profile.bankName;
      _accountNameController.text = profile.accountName;
      _sortCodeController.text = profile.sortCode;
      _accountNumberController.text = profile.accountNumber;
      _paymentNotesController.text = profile.paymentNotes;
      _vatRegistered = profile.vatRegistered;
      _vatNumberController.text = profile.vatNumber;
      _defaultInvoiceNotesController.text = profile.defaultInvoiceNotes;
      _defaultPaymentTermsController.text = profile.defaultPaymentTerms;
      _thankYouMessageController.text = profile.thankYouMessage;
      _defaultExtraHelperAmountController.text = _formatMoneyInput(
        profile.defaultExtraHelperAmount,
      );
      _defaultStairsAccessAmountController.text = _formatMoneyInput(
        profile.defaultStairsAccessAmount,
      );
      _defaultWaitingTimeAmountController.text = _formatMoneyInput(
        profile.defaultWaitingTimeAmount,
      );
      _defaultCollectionDeliveryAmountController.text = _formatMoneyInput(
        profile.defaultCollectionDeliveryAmount,
      );
      _defaultMileageRateController.text = _formatMoneyInput(
        profile.defaultMileageRate,
      );
      _logoPath = profile.logoPath;
      _logoUrl = resolveSavedVanBusinessLogoUrl(logoUrl);
      _logoStoragePath = _normalizeCloudStoragePath(logoStoragePath);
      _selectedLogoUpload = null;
      _logoName = (profile.hasLogo || _logoUrl != null) ? 'Saved logo' : null;
    });
  }

  Future<void> _pickLogo() async {
    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        requestFullMetadata: false,
      );
      if (pickedImage == null || !mounted) {
        return;
      }

      setState(() {
        _logoPath = pickedImage.path.trim().isEmpty
            ? null
            : pickedImage.path.trim();
        _selectedLogoUpload = pickedImage;
        _logoName = pickedImage.name;
        _logoStoragePath = null;
      });
      debugPrint(
        '[BusinessProfilePage] selected local logo path=${pickedImage.path}',
      );
    } catch (_) {
      if (mounted) {
        _showSnack('Could not pick logo.');
      }
    }
  }

  void _removeLogo() {
    setState(() {
      _logoPath = null;
      _logoUrl = null;
      _logoStoragePath = null;
      _selectedLogoUpload = null;
      _logoName = null;
    });
  }

  Future<void> _saveProfile() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final profile = VanBusinessProfileSettings(
      businessName: _businessNameController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      businessType: _businessTypeController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      emailAddress: _emailController.text.trim(),
      websiteOrSocialLink: _websiteController.text.trim(),
      addressLine1: _addressLine1Controller.text.trim(),
      addressLine2: _addressLine2Controller.text.trim(),
      townOrCity: _townController.text.trim(),
      postcode: _postcodeController.text.trim(),
      bankName: _bankNameController.text.trim(),
      accountName: _accountNameController.text.trim(),
      sortCode: _sortCodeController.text.trim(),
      accountNumber: _accountNumberController.text.trim(),
      paymentNotes: _paymentNotesController.text.trim(),
      vatRegistered: _vatRegistered,
      vatNumber: _vatNumberController.text.trim(),
      defaultInvoiceNotes: _defaultInvoiceNotesController.text.trim(),
      defaultPaymentTerms: _defaultPaymentTermsController.text.trim(),
      thankYouMessage: _thankYouMessageController.text.trim(),
      defaultExtraHelperAmount: _parseMoneyInput(
        _defaultExtraHelperAmountController.text,
      ),
      defaultStairsAccessAmount: _parseMoneyInput(
        _defaultStairsAccessAmountController.text,
      ),
      defaultWaitingTimeAmount: _parseMoneyInput(
        _defaultWaitingTimeAmountController.text,
      ),
      defaultCollectionDeliveryAmount: _parseMoneyInput(
        _defaultCollectionDeliveryAmountController.text,
      ),
      defaultMileageRate: _parseMoneyInput(_defaultMileageRateController.text),
      logoPath: resolveSavedVanBusinessLogoPath(_logoPath),
    );

    try {
      String? resolvedLogoUrl = resolveSavedVanBusinessLogoUrl(_logoUrl);
      String? resolvedLogoStoragePath = _normalizeCloudStoragePath(
        _logoStoragePath,
      );
      final selectedLocalLogoPath = resolveSavedVanBusinessLogoPath(_logoPath);
      debugPrint(
        '[BusinessProfilePage] save start localLogoPath=$selectedLocalLogoPath '
        'selectedUploadPath=${_selectedLogoUpload?.path ?? '(none)'} '
        'existingCloudPath=$resolvedLogoStoragePath existingCloudUrl=$resolvedLogoUrl',
      );

      var logoUploadFailed = false;
      String? logoUploadFailureMessage;
      if (_selectedLogoUpload == null &&
          selectedLocalLogoPath == null &&
          resolvedLogoUrl == null &&
          resolvedLogoStoragePath == null) {
        resolvedLogoUrl = null;
        resolvedLogoStoragePath = null;
      }

      if (_selectedLogoUpload != null) {
        try {
          final ownerUid = await VanFirebaseAuthService.instance
              .ensureCurrentUid(source: 'van_mate.business_logo_upload');
          if (ownerUid == null || ownerUid.trim().isEmpty) {
            throw StateError(
              'No signed-in Firebase user available for logo upload.',
            );
          }
          final uploadResult = await VanBusinessLogoStorageService.instance
              .uploadBusinessLogoWithMetadata(
                ownerUid: ownerUid,
                logoFile: _selectedLogoUpload!,
              );
          if (uploadResult == null) {
            logoUploadFailed = true;
            logoUploadFailureMessage = 'Upload returned no result.';
            debugPrint(
              '[BusinessProfilePage] logo upload failed: $logoUploadFailureMessage',
            );
          } else {
            resolvedLogoUrl = resolveSavedVanBusinessLogoUrl(
              uploadResult.downloadUrl,
            );
            resolvedLogoStoragePath = _normalizeCloudStoragePath(
              uploadResult.storagePath,
            );
            debugPrint(
              '[BusinessProfilePage] logo upload success '
              'cloudPath=$resolvedLogoStoragePath cloudUrl=$resolvedLogoUrl',
            );
          }
        } catch (error, stackTrace) {
          logoUploadFailed = true;
          logoUploadFailureMessage = error.toString();
          debugPrint('[BusinessProfilePage] logo upload failure error=$error');
          debugPrint('[BusinessProfilePage] logo upload stack=$stackTrace');
        }
      } else if (selectedLocalLogoPath != null &&
          resolvedLogoUrl == null &&
          resolvedLogoStoragePath == null) {
        try {
          final ownerUid = await VanFirebaseAuthService.instance
              .ensureCurrentUid(source: 'van_mate.business_logo_upload');
          if (ownerUid == null || ownerUid.trim().isEmpty) {
            throw StateError(
              'No signed-in Firebase user available for logo upload.',
            );
          }
          final uploadResult = await VanBusinessLogoStorageService.instance
              .uploadBusinessLogoWithMetadata(
                ownerUid: ownerUid,
                logoFile: XFile(selectedLocalLogoPath),
              );
          if (uploadResult == null) {
            logoUploadFailed = true;
            logoUploadFailureMessage = 'Upload returned no result.';
            debugPrint(
              '[BusinessProfilePage] logo upload failed: $logoUploadFailureMessage',
            );
          } else {
            resolvedLogoUrl = resolveSavedVanBusinessLogoUrl(
              uploadResult.downloadUrl,
            );
            resolvedLogoStoragePath = _normalizeCloudStoragePath(
              uploadResult.storagePath,
            );
            debugPrint(
              '[BusinessProfilePage] logo upload success '
              'cloudPath=$resolvedLogoStoragePath cloudUrl=$resolvedLogoUrl',
            );
          }
        } catch (error, stackTrace) {
          logoUploadFailed = true;
          logoUploadFailureMessage = error.toString();
          debugPrint('[BusinessProfilePage] logo upload failure error=$error');
          debugPrint('[BusinessProfilePage] logo upload stack=$stackTrace');
        }
      }

      await _storage.saveSettings(
        profile,
        logoUrl: resolvedLogoUrl,
        cloudLogoPath: resolvedLogoStoragePath,
      );
      debugPrint('[BusinessProfilePage] profile settings save success');
      _logoUrl = resolvedLogoUrl;
      _logoStoragePath = resolvedLogoStoragePath;
      _selectedLogoUpload = null;
      if (!mounted) {
        return;
      }
      if (logoUploadFailed) {
        _showSnack('Profile saved, but logo could not be uploaded.');
        debugPrint(
          '[BusinessProfilePage] profile saved with logo upload failure: '
          '$logoUploadFailureMessage',
        );
      } else {
        _showSnack('Business profile saved.');
      }
    } catch (error, stackTrace) {
      debugPrint('[BusinessProfilePage] profile save failure error=$error');
      debugPrint('[BusinessProfilePage] profile save stack=$stackTrace');
      if (mounted) {
        _showSnack('Could not save profile.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _normalizeCloudStoragePath(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }

    final lower = normalized.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('file:') ||
        normalized.contains('://') ||
        normalized.contains('\\') ||
        normalized.startsWith('/')) {
      return null;
    }

    return normalized;
  }

  Future<void> _resetChanges() async {
    setState(() {
      _isLoading = true;
    });
    await _loadProfile();
    if (mounted) {
      _showSnack('Changes reset.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  double _parseMoneyInput(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '').trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '-') {
      return 0;
    }
    return double.tryParse(cleaned) ?? 0;
  }

  String _formatMoneyInput(double value) {
    if (value <= 0) {
      return '';
    }
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Business Profile'),
        leadingWidth: 96,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: VanBackBusinessHubButtons(
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            bottom: false,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      bottomInset + keyboardInset + 24,
                    ),
                    children: [
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Business Profile',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your business details used across quotes, invoices and reports.',
                              style: TextStyle(
                                fontSize: 13.2,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.76),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Business Details',
                        subtitle: 'How your business appears on documents.',
                        child: _ResponsiveFields(
                          children: [
                            _ProfileField(
                              controller: _businessNameController,
                              label: 'Business name',
                              hint: 'Business name',
                            ),
                            _ProfileField(
                              controller: _ownerNameController,
                              label: 'Owner name',
                              hint: 'Owner name',
                            ),
                            _ProfileField(
                              controller: _businessTypeController,
                              label: 'Business type',
                              hint: 'Sole trader, partnership, limited company',
                            ),
                            _ProfileField(
                              controller: _phoneController,
                              label: 'Phone number',
                              hint: 'Phone number',
                              keyboardType: TextInputType.phone,
                            ),
                            _ProfileField(
                              controller: _emailController,
                              label: 'Email address',
                              hint: 'Email address',
                              keyboardType: TextInputType.emailAddress,
                            ),
                            _ProfileField(
                              controller: _websiteController,
                              label: 'Website or social link',
                              hint: 'https://... or @profile',
                              keyboardType: TextInputType.url,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Address Details',
                        subtitle: 'Used on invoices and business paperwork.',
                        child: _ResponsiveFields(
                          children: [
                            _ProfileField(
                              controller: _addressLine1Controller,
                              label: 'Address line 1',
                              hint: 'Street address',
                            ),
                            _ProfileField(
                              controller: _addressLine2Controller,
                              label: 'Address line 2',
                              hint: 'Apartment, suite, unit, etc.',
                            ),
                            _ProfileField(
                              controller: _townController,
                              label: 'Town / city',
                              hint: 'Town or city',
                            ),
                            _ProfileField(
                              controller: _postcodeController,
                              label: 'Postcode',
                              hint: 'SW1A 1AA',
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Payment Details',
                        subtitle: 'Bank details and payment notes.',
                        child: _ResponsiveFields(
                          children: [
                            _ProfileField(
                              controller: _bankNameController,
                              label: 'Bank name',
                              hint: 'Your bank',
                            ),
                            _ProfileField(
                              controller: _accountNameController,
                              label: 'Account name',
                              hint: 'Account holder name',
                            ),
                            _ProfileField(
                              controller: _sortCodeController,
                              label: 'Sort code',
                              hint: '12-34-56',
                              keyboardType: TextInputType.number,
                            ),
                            _ProfileField(
                              controller: _accountNumberController,
                              label: 'Account number',
                              hint: '12345678',
                              keyboardType: TextInputType.number,
                            ),
                            _ProfileField(
                              controller: _paymentNotesController,
                              label: 'Payment notes',
                              hint: 'Bank transfer, due on receipt, etc.',
                              maxLines: 3,
                              keyboardType: TextInputType.multiline,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Tax Details',
                        subtitle: 'VAT status for future documents.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.white.withValues(alpha: 0.06),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: _vatRegistered,
                                onChanged: (value) {
                                  setState(() {
                                    _vatRegistered = value;
                                    if (!value) {
                                      _vatNumberController.clear();
                                    }
                                  });
                                },
                                title: const Text(
                                  'VAT registered',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  'Turn on if you charge VAT.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.70),
                                  ),
                                ),
                              ),
                            ),
                            if (_vatRegistered) ...[
                              const SizedBox(height: 10),
                              _ProfileField(
                                controller: _vatNumberController,
                                label: 'VAT number',
                                hint: 'GB123456789',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Invoice Defaults',
                        subtitle:
                            'Reusable text and quick-extra charges for future invoices.',
                        child: _ResponsiveFields(
                          children: [
                            _ProfileField(
                              controller: _defaultInvoiceNotesController,
                              label: 'Default invoice notes',
                              hint: 'Extra notes to show on invoices',
                              maxLines: 3,
                              keyboardType: TextInputType.multiline,
                            ),
                            _ProfileField(
                              controller: _defaultPaymentTermsController,
                              label: 'Default payment terms',
                              hint: 'Due on receipt, 14 days, etc.',
                              maxLines: 3,
                              keyboardType: TextInputType.multiline,
                            ),
                            _ProfileField(
                              controller: _thankYouMessageController,
                              label: 'Thank you message',
                              hint: 'Thanks for your business',
                              maxLines: 3,
                              keyboardType: TextInputType.multiline,
                            ),
                            _ProfileField(
                              controller: _defaultExtraHelperAmountController,
                              label: 'Extra helper default amount',
                              hint: '20.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              prefixText: '£',
                            ),
                            _ProfileField(
                              controller: _defaultStairsAccessAmountController,
                              label: 'Stairs/access default amount',
                              hint: '10.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              prefixText: '£',
                            ),
                            _ProfileField(
                              controller: _defaultWaitingTimeAmountController,
                              label: 'Waiting time default amount',
                              hint: '15.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              prefixText: '£',
                            ),
                            _ProfileField(
                              controller:
                                  _defaultCollectionDeliveryAmountController,
                              label: 'Collection/delivery default amount',
                              hint: '10.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              prefixText: '£',
                            ),
                            _ProfileField(
                              controller: _defaultMileageRateController,
                              label: 'Mileage default rate',
                              hint: '1.50',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              prefixText: '£',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Business Logo',
                        subtitle: 'Add a logo for invoices and reports later.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    color: Colors.white.withValues(alpha: 0.06),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: buildVanBusinessLogoPreview(
                                    _logoPath,
                                    logoUrl: _logoUrl,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _logoName?.trim().isNotEmpty == true
                                            ? 'Selected: $_logoName'
                                            : 'No logo selected yet.',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.84,
                                          ),
                                          height: 1.35,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          SizedBox(
                                            height: 42,
                                            child: FilledButton.icon(
                                              onPressed: _pickLogo,
                                              icon: Icon(
                                                _logoPath == null &&
                                                        _logoUrl == null
                                                    ? Icons.add_photo_alternate
                                                    : Icons.swap_horiz_rounded,
                                              ),
                                              label: Text(
                                                _logoPath == null &&
                                                        _logoUrl == null
                                                    ? 'Add logo'
                                                    : 'Change logo',
                                              ),
                                            ),
                                          ),
                                          if (_logoPath != null ||
                                              _logoUrl != null)
                                            SizedBox(
                                              height: 42,
                                              child: OutlinedButton.icon(
                                                onPressed: _removeLogo,
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                label: const Text('Remove'),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _logoUrl != null
                                  ? 'Logo is saved to Firebase and available across your profile, invoices, and booking link.'
                                  : (_logoPath != null
                                        ? 'Logo selected. Save profile to sync it to Firebase for invoices and booking links.'
                                        : 'Add and save a logo to sync it to Firebase for invoices and booking links.'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.62),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _BottomActions(
                        saving: _isSaving,
                        onSave: _saveProfile,
                        onReset: _resetChanges,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.8,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final String? prefixText;

  const _ProfileField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.prefixText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      onSubmitted: maxLines > 1
          ? null
          : (_) => FocusScope.of(context).nextFocus(),
      scrollPadding: const EdgeInsets.only(bottom: 120),
      style: kVanMateFieldTextStyle,
      decoration: vanMateFieldDecoration(
        label: label,
        hintText: hint,
        labelOpacity: 0.68,
        hintOpacity: 0.48,
        prefixText: prefixText,
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveFields({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        if (!wide) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                if (child != children.last) const SizedBox(height: 10),
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var index = 0; index < children.length; index += 2) {
          final first = children[index];
          final second = index + 1 < children.length
              ? children[index + 1]
              : const SizedBox.shrink();
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: first),
                const SizedBox(width: 10),
                Expanded(child: second),
              ],
            ),
          );
          if (index + 2 < children.length) {
            rows.add(const SizedBox(height: 10));
          }
        }
        return Column(children: rows);
      },
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onReset;

  const _BottomActions({
    required this.saving,
    required this.onSave,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 480;
        final saveButton = SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4A7DFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(saving ? 'Saving...' : 'Save profile'),
          ),
        );
        final resetButton = SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: saving ? null : onReset,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Reset changes'),
          ),
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [saveButton, const SizedBox(height: 10), resetButton],
          );
        }

        return Row(
          children: [
            Expanded(child: saveButton),
            const SizedBox(width: 10),
            Expanded(child: resetButton),
          ],
        );
      },
    );
  }
}
