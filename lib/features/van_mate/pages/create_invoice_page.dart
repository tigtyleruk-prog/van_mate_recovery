import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_business_logo_support.dart';
import '../helpers/van_invoice_extra_suggestions.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_business_profile.dart';
import '../models/van_invoice_draft.dart';
import '../services/van_business_logo_storage_service.dart';
import '../services/van_business_profile_storage.dart';
import '../services/van_firebase_auth_service.dart';
import '../services/van_invoice_number_storage.dart';
import 'create_invoice_hub_page.dart';
import 'van_invoice_preview_page.dart';
import 'driver_customer_reply_mock_page.dart';
import '../widgets/van_form_field_styles.dart';
import '../widgets/van_back_business_hub_buttons.dart';

Future<void> openCreateInvoiceMockPage(
  BuildContext context,
  DriverCustomerReplyMockData reply,
) {
  return openCreateInvoiceHubPage(context, reply);
}

class CreateInvoicePage extends StatefulWidget {
  const CreateInvoicePage({super.key, required this.reply});

  final DriverCustomerReplyMockData reply;

  @override
  State<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage> {
  final ImagePicker _imagePicker = ImagePicker();
  final VanBusinessProfileStorage _businessProfileStorage =
      VanBusinessProfileStorage.instance;
  final VanInvoiceNumberStorage _invoiceNumberStorage =
      VanInvoiceNumberStorage.instance;
  late final TextEditingController _businessNameController;
  late final TextEditingController _contactNameController;
  late final TextEditingController _businessPhoneController;
  late final TextEditingController _businessEmailController;
  late final TextEditingController _businessAddressController;
  late final TextEditingController _paymentInstructionsController;
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;
  late final TextEditingController _billingAddressController;
  late final TextEditingController _customerEmailController;
  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _invoiceDateController;
  late final TextEditingController _dueDateController;
  late final TextEditingController _jobReferenceController;
  late final TextEditingController _jobDescriptionController;
  late final TextEditingController _estimatedMilesController;
  late final TextEditingController _mileageChargeController;
  late final TextEditingController _invoiceNotesController;
  late final ValueNotifier<double> _invoiceTotalNotifier;
  String? _selectedLogoPath;
  String? _selectedLogoUrl;
  XFile? _selectedLogoUpload;
  String? _selectedLogoName;
  String _defaultInvoiceNumber = '';

  final List<_InvoiceLineItemDraft> _lineItems = <_InvoiceLineItemDraft>[];
  final Set<String> _selectedExtras = <String>{};
  final Set<String> _suggestedExtras = <String>{};

  @override
  void initState() {
    super.initState();
    final reply = widget.reply;
    final defaults = const VanBusinessProfile.defaults();
    final quotePaymentInstructions = resolveVanMatePaymentInstructions(
      reply.quotePaymentInstructions.isNotEmpty
          ? reply.quotePaymentInstructions
          : defaults.paymentInstructions,
    );
    final quoteExtras = reply.quoteExtras
        .map((item) => sanitizeVanText(item).trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final quoteExtraLineItems = buildVanInvoiceQuoteExtraLineItems(quoteExtras);
    final baseQuoteAmount = resolveVanInvoiceBaseQuoteAmount(
      quoteAmount: reply.quoteAmount ?? 0,
      quoteExtraLineItems: quoteExtraLineItems,
    );
    _businessNameController = TextEditingController(
      text: defaults.businessName,
    );
    _contactNameController = TextEditingController(text: defaults.contactName);
    _businessPhoneController = TextEditingController(text: defaults.phone);
    _businessEmailController = TextEditingController(text: defaults.email);
    _businessAddressController = TextEditingController(
      text: defaults.businessAddress,
    );
    _paymentInstructionsController = TextEditingController(
      text: quotePaymentInstructions,
    );
    _customerNameController = TextEditingController(text: reply.customerName);
    _customerPhoneController = TextEditingController(text: reply.phoneNumber);
    _billingAddressController = TextEditingController(text: reply.address);
    _customerEmailController = TextEditingController(text: reply.customerEmail);
    _invoiceNumberController = TextEditingController(text: '');
    _invoiceDateController = TextEditingController(
      text: '${reply.jobDateLabel} ${reply.jobTimeLabel}'.trim(),
    );
    _dueDateController = TextEditingController(
      text: VanInvoiceDraft.dueOnReceiptLabel,
    );
    _jobReferenceController = TextEditingController(text: reply.jobTitle);
    _jobDescriptionController = TextEditingController(
      text: 'Invoice for completed ${reply.jobTitle} work.',
    );
    _estimatedMilesController = TextEditingController(text: '');
    _mileageChargeController = TextEditingController(text: '');
    _invoiceNotesController = TextEditingController(text: '');
    _invoiceTotalNotifier = ValueNotifier<double>(0);

    _lineItems.add(
      _InvoiceLineItemDraft(
        description: reply.jobTitle,
        quantity: '1',
        amount: baseQuoteAmount.toStringAsFixed(2),
      ),
    );
    for (final item in quoteExtraLineItems) {
      _lineItems.add(
        _InvoiceLineItemDraft(
          description: item.description,
          quantity: item.quantity.toString(),
          amount: item.amount.toStringAsFixed(2),
          extraKey: item.extraKey,
        ),
      );
    }
    _syncQuickExtraState();
    _recalculateInvoiceSummary();

    unawaited(_loadSavedBusinessProfile());
    unawaited(_loadInvoiceNumber());
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _contactNameController.dispose();
    _businessPhoneController.dispose();
    _businessEmailController.dispose();
    _businessAddressController.dispose();
    _paymentInstructionsController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _billingAddressController.dispose();
    _customerEmailController.dispose();
    _invoiceNumberController.dispose();
    _invoiceDateController.dispose();
    _dueDateController.dispose();
    _jobReferenceController.dispose();
    _jobDescriptionController.dispose();
    _estimatedMilesController.dispose();
    _mileageChargeController.dispose();
    _invoiceNotesController.dispose();
    _invoiceTotalNotifier.dispose();
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _recalculateInvoiceSummary() {
    _invoiceTotalNotifier.value = _invoiceTotal;
  }

  void _handleLineItemChanged() {
    setState(() {
      _syncQuickExtraState();
    });
  }

  void _handleMileageFieldChanged() {
    setState(() {
      _syncQuickExtraState();
      _recalculateInvoiceSummary();
    });
  }

  Set<String> _buildSuggestedExtras() {
    return buildSuggestedInvoiceExtraKeys(
      checklistResponses: widget.reply.checklistResponses.map(
        (response) => VanInvoiceReplyAnswer(
          question: response.question,
          answer: response.answer,
          note: response.note ?? '',
        ),
      ),
      customQuestionResponses: widget.reply.customQuestionResponses.map(
        (response) => VanInvoiceReplyAnswer(
          question: response.question,
          answer: response.answer,
        ),
      ),
      jobTitle: widget.reply.jobTitle,
      jobDescription: _jobDescriptionController.text,
      additionalNotes: widget.reply.additionalNotes,
      quoteNotes: widget.reply.quoteNotes,
      quoteMessage: widget.reply.quoteMessage,
      estimatedMiles: _estimatedMilesController.text,
      hasMileageCharge: _parseMoney(_mileageChargeController.text) > 0,
    );
  }

  VanBusinessProfile _currentBusinessProfile() {
    return VanBusinessProfile(
      businessName: _businessNameController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().businessName
          : _businessNameController.text.trim(),
      contactName: _contactNameController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().contactName
          : _contactNameController.text.trim(),
      phone: _businessPhoneController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().phone
          : _businessPhoneController.text.trim(),
      email: _businessEmailController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().email
          : _businessEmailController.text.trim(),
      businessAddress: _businessAddressController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().businessAddress
          : _businessAddressController.text.trim(),
      paymentInstructions: resolveVanMatePaymentInstructions(
        _paymentInstructionsController.text,
      ),
      defaultExtraHelperAmount: 0,
      defaultStairsAccessAmount: 0,
      defaultWaitingTimeAmount: 0,
      defaultCollectionDeliveryAmount: 0,
      defaultMileageRate: 0,
      logoPath: resolveSavedVanBusinessLogoPath(_selectedLogoPath),
      logoUrl: resolveSavedVanBusinessLogoUrl(_selectedLogoUrl),
    );
  }

  VanInvoiceDraft _buildInvoiceDraft() {
    _syncQuickExtraState();
    final businessProfile = _currentBusinessProfile();
    final invoice = widget.reply.toInvoiceDraft(
      businessProfile: businessProfile,
      invoiceNumber: _invoiceNumberController.text.trim().isEmpty
          ? _defaultInvoiceNumber
          : _invoiceNumberController.text.trim(),
    );

    return invoice.copyWith(
      customerName: _customerNameController.text.trim().isEmpty
          ? widget.reply.customerName
          : _customerNameController.text.trim(),
      customerPhone: _customerPhoneController.text.trim().isEmpty
          ? widget.reply.phoneNumber
          : _customerPhoneController.text.trim(),
      billingAddress: _billingAddressController.text.trim().isEmpty
          ? widget.reply.address
          : _billingAddressController.text.trim(),
      customerEmail: _customerEmailController.text.trim().isEmpty
          ? widget.reply.customerEmail
          : _customerEmailController.text.trim(),
      invoiceDate: _invoiceDateController.text.trim().isEmpty
          ? '${widget.reply.jobDateLabel} ${widget.reply.jobTimeLabel}'.trim()
          : _invoiceDateController.text.trim(),
      dueDate: _dueDateController.text.trim(),
      jobReference: _jobReferenceController.text.trim().isEmpty
          ? widget.reply.jobTitle
          : _jobReferenceController.text.trim(),
      jobDescription: _jobDescriptionController.text.trim().isEmpty
          ? invoice.jobDescription
          : _jobDescriptionController.text.trim(),
      lineItems: [
        for (final item in _lineItems)
          VanInvoiceLineItem(
            description: item.descriptionController.text.trim().isEmpty
                ? 'Line item'
                : item.descriptionController.text.trim(),
            quantity: _parseQuantity(item.quantityController.text),
            amount: _parseMoney(item.amountController.text),
            extraKey: item.extraKey,
          ),
      ],
      estimatedMiles: _estimatedMilesController.text.trim(),
      mileageCharge: _parseMoney(_mileageChargeController.text),
      paymentInstructions: _paymentInstructionsController.text.trim(),
      invoiceNotes: _invoiceNotesController.text.trim().isEmpty
          ? invoice.invoiceNotes
          : _invoiceNotesController.text.trim(),
    );
  }

  bool _validateDueDateBeforeInvoiceAction() {
    if (_dueDateController.text.trim().isNotEmpty) {
      return true;
    }
    _showSnack(
      'Add a due date or choose Due on receipt before saving the invoice.',
    );
    return false;
  }

  Future<void> _previewInvoice() async {
    if (!_validateDueDateBeforeInvoiceAction()) {
      return;
    }
    await openVanInvoicePreviewPage(context, _buildInvoiceDraft());
  }

  void _applyBusinessProfile(VanBusinessProfile profile) {
    _businessNameController.text = profile.businessName;
    _contactNameController.text = profile.contactName;
    _businessPhoneController.text = profile.phone;
    _businessEmailController.text = profile.email;
    _businessAddressController.text = profile.businessAddress;
    _paymentInstructionsController.text = profile.paymentInstructions;
    _selectedLogoPath = resolveSavedVanBusinessLogoPath(profile.logoPath);
    _selectedLogoUrl = resolveSavedVanBusinessLogoUrl(profile.logoUrl);
    _selectedLogoUpload = null;
    _selectedLogoName = profile.hasLogo ? 'Saved logo' : null;
  }

  Future<void> _loadSavedBusinessProfile() async {
    final profile = await _businessProfileStorage.loadCanonicalProfile();
    if (!mounted) {
      return;
    }

    setState(() {
      _applyBusinessProfile(profile);
    });
  }

  Future<void> _loadInvoiceNumber() async {
    _defaultInvoiceNumber = await _invoiceNumberStorage.peekNextInvoiceNumber();
    if (!mounted || _invoiceNumberController.text.trim().isNotEmpty) {
      return;
    }

    setState(() {
      _invoiceNumberController.text = _defaultInvoiceNumber;
    });
  }

  Future<void> _saveBusinessProfile() async {
    final existingProfile = await _businessProfileStorage
        .loadCanonicalProfile();
    String? resolvedLogoUrl = resolveSavedVanBusinessLogoUrl(_selectedLogoUrl);
    final selectedLogoPath = resolveSavedVanBusinessLogoPath(_selectedLogoPath);
    if (selectedLogoPath == null) {
      resolvedLogoUrl = null;
    } else if (_selectedLogoUpload != null) {
      resolvedLogoUrl = null;
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.business_logo_upload',
      );
      if (ownerUid != null && ownerUid.trim().isNotEmpty) {
        resolvedLogoUrl = await VanBusinessLogoStorageService.instance
            .uploadBusinessLogo(
              ownerUid: ownerUid,
              logoFile: _selectedLogoUpload!,
            );
      }
    }
    final profile = existingProfile.copyWith(
      businessName: _businessNameController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().businessName
          : _businessNameController.text.trim(),
      contactName: _contactNameController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().contactName
          : _contactNameController.text.trim(),
      phone: _businessPhoneController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().phone
          : _businessPhoneController.text.trim(),
      email: _businessEmailController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().email
          : _businessEmailController.text.trim(),
      businessAddress: _businessAddressController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().businessAddress
          : _businessAddressController.text.trim(),
      paymentInstructions: resolveVanMatePaymentInstructions(
        _paymentInstructionsController.text,
      ),
      logoPath: resolveSavedVanBusinessLogoPath(_selectedLogoPath),
      logoUrl: resolvedLogoUrl,
    );
    await _businessProfileStorage.save(profile);
    if (_selectedLogoUpload != null) {
      _selectedLogoUpload = null;
    }
    _selectedLogoUrl = resolvedLogoUrl;
    if (!mounted) {
      return;
    }

    _showSnack('Business profile saved.');
  }

  Future<void> _resetBusinessProfile() async {
    await _businessProfileStorage.clear();
    if (!mounted) {
      return;
    }

    setState(() {
      _applyBusinessProfile(const VanBusinessProfile.defaults());
    });
    _showSnack('Business profile reset.');
  }

  Future<void> _pickLogo() async {
    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        requestFullMetadata: false,
      );

      if (pickedImage == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedLogoPath = pickedImage.path.trim().isEmpty
            ? null
            : pickedImage.path.trim();
        _selectedLogoUpload = pickedImage;
        _selectedLogoName = pickedImage.name;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Could not pick logo.');
    }
  }

  void _removeLogo() {
    setState(() {
      _selectedLogoPath = null;
      _selectedLogoUrl = null;
      _selectedLogoUpload = null;
      _selectedLogoName = null;
    });
  }

  String _moneyText(num amount) => formatCurrency(amount);

  double _parseMoney(String value) => parseCurrencyValue(value);

  int _parseQuantity(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return 1;
    }
    return parsed;
  }

  double _lineItemTotal(_InvoiceLineItemDraft item) {
    return _parseQuantity(item.quantityController.text) *
        _parseMoney(item.amountController.text);
  }

  double get _invoiceTotal {
    final lineItemTotal = _lineItems.fold<double>(
      0,
      (total, item) => total + _lineItemTotal(item),
    );
    final mileageCharge = _parseMoney(_mileageChargeController.text);
    return lineItemTotal + mileageCharge;
  }

  void _saveInvoice() {
    if (!_validateDueDateBeforeInvoiceAction()) {
      return;
    }
    _syncQuickExtraState();
    setState(() {});
    DriverReplyMockState.instance.setInvoiceCreated(
      true,
      jobId: widget.reply.invoiceHistoryKey,
    );
    _showSnack('Invoice saved.');
  }

  void _addExtraLineItem(_InvoiceExtraPreset preset) {
    if (preset.key != 'custom' && _selectedExtras.contains(preset.key)) {
      return;
    }

    setState(() {
      if (preset.key == 'custom') {
        _lineItems.add(
          _InvoiceLineItemDraft(
            description: preset.description,
            quantity: preset.quantity,
            amount: preset.amount,
            extraKey: preset.key,
          ),
        );
      } else if (preset.key == 'mileage') {
        if (_hasMileageLineItem || _hasActiveMileageCharge) {
          _clearMileageExtra();
        } else {
          _lineItems.add(
            _InvoiceLineItemDraft(
              description: preset.description,
              quantity: preset.quantity,
              amount: preset.amount,
              extraKey: preset.key,
            ),
          );
        }
      } else {
        final existing = _findMatchingExtraItems(preset.key);
        if (existing.isNotEmpty) {
          _removeExtraItems(existing);
        } else {
          _lineItems.add(
            _InvoiceLineItemDraft(
              description: preset.description,
              quantity: preset.quantity,
              amount: preset.amount,
              extraKey: preset.key,
            ),
          );
        }
      }
      _syncQuickExtraState();
    });
    _recalculateInvoiceSummary();
  }

  void _removeLineItem(_InvoiceLineItemDraft item) {
    setState(() {
      _selectedExtras.remove(item.extraKey);
      _lineItems.remove(item);
    });

    item.dispose();
    _syncQuickExtraState();
    _recalculateInvoiceSummary();
  }

  void _removeExtraItems(List<_InvoiceLineItemDraft> items) {
    for (final item in items) {
      _selectedExtras.remove(item.extraKey);
      _lineItems.remove(item);
      item.dispose();
    }
  }

  void _clearMileageExtra() {
    final mileageItems = _findMatchingExtraItems('mileage');
    _removeExtraItems(mileageItems);
    _mileageChargeController.text = '';
  }

  List<_InvoiceLineItemDraft> _findMatchingExtraItems(String key) {
    return _lineItems.where((item) => _extraKeyForItem(item) == key).toList();
  }

  String? _extraKeyForItem(_InvoiceLineItemDraft item) {
    final existingKey = _normalizeQuickExtraKey(item.extraKey);
    if (existingKey != null) {
      return existingKey;
    }
    return _extraKeyForDescription(item.descriptionController.text);
  }

  String? _extraKeyForDescription(String value) {
    return canonicalizeVanInvoiceExtraKey(value);
  }

  String? _normalizeQuickExtraKey(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized == 'custom' ||
        normalized == 'collection_delivery' ||
        normalized == 'waiting_time' ||
        normalized == 'stairs' ||
        normalized == 'helper' ||
        normalized == 'mileage') {
      return normalized;
    }
    return null;
  }

  bool get _hasMileageLineItem => _findMatchingExtraItems('mileage').isNotEmpty;

  bool get _hasActiveMileageCharge =>
      _parseMoney(_mileageChargeController.text) > 0;

  void _syncQuickExtraState() {
    final selected = <String>{};
    for (final item in _lineItems) {
      final key = _extraKeyForItem(item);
      item.extraKey = key;
      if (key != null) {
        selected.add(key);
      }
    }
    if (_hasMileageLineItem || _hasActiveMileageCharge) {
      selected.add('mileage');
    }
    final suggested = _buildSuggestedExtras()..removeAll(selected);
    _selectedExtras
      ..clear()
      ..addAll(selected);
    _suggestedExtras
      ..clear()
      ..addAll(suggested);
  }

  Widget _buildShellCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
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
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? subtitle, IconData? icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, size: 17, color: Colors.white),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.70),
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(
    String label, {
    required Color color,
    IconData? icon,
    bool filled = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: filled
            ? color.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontSize: 11.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    VoidCallback? onChanged,
    String? hint,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
    String? suffixText,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      onChanged: onChanged == null ? null : (_) => onChanged(),
      style: kVanMateFieldTextStyle,
      decoration: vanMateFieldDecoration(
        label: label,
        hintText: hint,
        prefixText: prefixText,
        suffixText: suffixText,
        labelOpacity: 0.68,
        hintOpacity: 0.50,
      ),
    );
  }

  Widget _buildLogoSquare({required double size}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: Colors.white.withValues(alpha: 0.08),
          child: buildVanBusinessLogoPreview(
            _selectedLogoPath,
            logoUrl: _selectedLogoUrl,
          ),
        ),
      ),
    );
  }

  Widget _buildLogoCard() {
    final hasLogo = _selectedLogoPath != null || _selectedLogoUrl != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business logo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: _buildLogoSquare(size: 72),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLogo
                          ? (_selectedLogoName?.isNotEmpty == true
                                ? 'Selected: $_selectedLogoName'
                                : 'Logo selected for this invoice preview.')
                          : 'Add your business logo later to brand the invoice.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.76),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: _pickLogo,
                            icon: Icon(
                              hasLogo
                                  ? Icons.swap_horiz_outlined
                                  : Icons.add_photo_alternate_outlined,
                            ),
                            label: Text(hasLogo ? 'Change logo' : 'Add logo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        if (hasLogo)
                          SizedBox(
                            height: 42,
                            child: OutlinedButton.icon(
                              onPressed: _removeLogo,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remove logo'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedLogoUrl != null
                          ? 'Logo is saved to Firebase and shared across invoices and booking links.'
                          : (hasLogo
                                ? 'Logo selected. Save business profile to sync it to Firebase.'
                                : 'Save your profile to sync a logo across invoices and booking links.'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.58),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemRow(_InvoiceLineItemDraft item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 520;
          final controls = <Widget>[
            Expanded(
              flex: 3,
              child: _buildInput(
                controller: item.descriptionController,
                label: 'Description',
                hint: 'Line item description',
                onChanged: _handleLineItemChanged,
              ),
            ),
            if (!stacked) const SizedBox(width: 10),
            SizedBox(
              width: stacked ? double.infinity : 82,
              child: _buildInput(
                controller: item.quantityController,
                label: 'Qty',
                keyboardType: TextInputType.number,
                onChanged: _recalculateInvoiceSummary,
              ),
            ),
            if (!stacked) const SizedBox(width: 10),
            SizedBox(
              width: stacked ? double.infinity : 110,
              child: _buildInput(
                controller: item.amountController,
                label: 'Amount',
                prefixText: '\u00A3',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: _recalculateInvoiceSummary,
              ),
            ),
            if (!stacked && item.extraKey != null) ...[
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _removeLineItem(item),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ];

          final stackedControls = <Widget>[
            _buildInput(
              controller: item.descriptionController,
              label: 'Description',
              hint: 'Line item description',
              onChanged: _handleLineItemChanged,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    controller: item.quantityController,
                    label: 'Qty',
                    keyboardType: TextInputType.number,
                    onChanged: _recalculateInvoiceSummary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInput(
                    controller: item.amountController,
                    label: 'Amount',
                    prefixText: '\u00A3',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: _recalculateInvoiceSummary,
                  ),
                ),
                if (item.extraKey != null) ...[
                  const SizedBox(width: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _removeLineItem(item),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white.withValues(alpha: 0.06),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked) ...stackedControls else Row(children: controls),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    item.quantityController,
                    item.amountController,
                  ]),
                  builder: (context, _) {
                    return Text(
                      'Line total: ${_moneyText(_lineItemTotal(item))}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExtraChip(_InvoiceExtraPreset preset) {
    final selected = _selectedExtras.contains(preset.key);
    final suggested = !selected && _suggestedExtras.contains(preset.key);
    final active = selected || suggested;
    final activeColor = selected
        ? const Color(0xFF58D0A4)
        : const Color(0xFF4A7DFF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: selected ? null : () => _addExtraLineItem(preset),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? const Color(0xFF58D0A4).withValues(alpha: 0.18)
                : suggested
                ? const Color(0xFF4A7DFF).withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: selected
                  ? const Color(0xFF58D0A4).withValues(alpha: 0.30)
                  : suggested
                  ? const Color(0xFF4A7DFF).withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.check_circle
                    : suggested
                    ? Icons.auto_awesome
                    : Icons.circle_outlined,
                size: 13,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                preset.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: active ? 0.98 : 0.78),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (suggested) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: activeColor.withValues(alpha: 0.16),
                    border: Border.all(
                      color: activeColor.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Text(
                    'Suggested',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 9.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpgradeCard() {
    const ideas = <String>[
      'Save business profile',
      'Add logo to PDF',
      'Auto invoice numbers',
      'Branded invoice templates',
      'Weekly job report PDF',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business upgrade ideas',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invoice creation works for everyone. Small upgrades can add polish later.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.70),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          for (final idea in ideas) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A7DFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      idea,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildButtonRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 520;

        final primaryButtons = <Widget>[
          _buildActionButton(
            label: 'Preview invoice',
            icon: Icons.visibility_outlined,
            color: const Color(0xFF4A7DFF),
            filled: true,
            onTap: _previewInvoice,
          ),
        ];

        final secondaryButtons = <Widget>[
          _buildActionButton(
            label: 'Save invoice',
            icon: Icons.save_outlined,
            color: const Color(0xFF58D0A4),
            onTap: _saveInvoice,
          ),
        ];

        if (stacked) {
          return Column(
            children: [
              primaryButtons.first,
              const SizedBox(height: 10),
              secondaryButtons.first,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: primaryButtons.first),
            const SizedBox(width: 10),
            Expanded(child: secondaryButtons.first),
          ],
        );
      },
    );
  }

  Widget _buildInvoiceSummaryCard() {
    final itemCount = _lineItems.length.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invoice summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 620;
              final tileWidth = wide
                  ? (constraints.maxWidth - 20) / 3
                  : constraints.maxWidth;
              final tiles = <Widget>[
                ValueListenableBuilder<double>(
                  valueListenable: _invoiceTotalNotifier,
                  builder: (context, total, _) {
                    return _buildInfoTile('Total due', _moneyText(total));
                  },
                ),
                _buildInfoTile('Items', itemCount),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _businessNameController,
                  builder: (context, value, _) {
                    final businessName = value.text.trim().isEmpty
                        ? const VanBusinessProfile.defaults().businessName
                        : value.text.trim();
                    return _buildInfoTile('Business', businessName);
                  },
                ),
              ];

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final tile in tiles)
                    SizedBox(width: tileWidth, child: tile),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
    required Color color,
    IconData? icon,
    bool filled = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: filled
                ? color.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.24)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return _buildShellCard(child: child);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final invoiceStatus = DriverReplyMockState.instance.invoiceSent
        ? 'Invoice sent'
        : (DriverReplyMockState.instance.invoiceCreated
              ? 'Invoice created'
              : 'Ready to invoice');
    final exactPinChip = widget.reply.exactPinShared
        ? 'Exact pin saved'
        : widget.reply.requestExactPin
        ? 'Exact pin available'
        : 'Exact pin not requested';
    final invoiceReadyChip = 'Ready to invoice';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _dismissKeyboard,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  28 + bottomPadding + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VanBackBusinessHubButtons(
                          onBack: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Create invoice',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a final invoice for completed work.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.76),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: const Color(
                                        0xFF4A7DFF,
                                      ).withValues(alpha: 0.18),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF4A7DFF,
                                        ).withValues(alpha: 0.30),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_outlined,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Invoice for ${widget.reply.customerName}',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          widget.reply.jobTitle,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: Colors.white.withValues(
                                                  alpha: 0.74,
                                                ),
                                                height: 1.35,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildStatusChip(
                                    widget.reply.isCompleted
                                        ? 'Completed job'
                                        : 'Ready to invoice',
                                    color: const Color(0xFF58D0A4),
                                    icon: Icons.check_circle,
                                    filled: true,
                                  ),
                                  _buildStatusChip(
                                    exactPinChip,
                                    color: const Color(0xFF58D0A4),
                                    icon: Icons.location_on,
                                  ),
                                  _buildStatusChip(
                                    invoiceReadyChip,
                                    color: const Color(0xFF4A7DFF),
                                    icon: Icons.receipt_long,
                                    filled: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final wide = constraints.maxWidth >= 620;
                                  final tileWidth = wide
                                      ? (constraints.maxWidth - 10) / 2
                                      : constraints.maxWidth;
                                  final tiles = <Widget>[
                                    _buildInfoTile(
                                      'Invoice for',
                                      widget.reply.customerName,
                                    ),
                                    _buildInfoTile(
                                      'Job',
                                      widget.reply.jobTitle,
                                    ),
                                    _buildInfoTile(
                                      'Job date',
                                      widget.reply.jobDateLabel,
                                    ),
                                    _buildInfoTile(
                                      'Address',
                                      widget.reply.address,
                                    ),
                                    _buildInfoTile(
                                      'Quote amount',
                                      _moneyText(45),
                                    ),
                                  ];

                                  return Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      for (final tile in tiles)
                                        SizedBox(width: tileWidth, child: tile),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              _buildSectionHeader(
                                'Your business details',
                                subtitle:
                                    'Use this section to brand the invoice later.',
                                icon: Icons.storefront_outlined,
                              ),
                              const SizedBox(height: 12),
                              _buildLogoCard(),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final wide = constraints.maxWidth >= 620;
                                  final tileWidth = wide
                                      ? (constraints.maxWidth - 10) / 2
                                      : constraints.maxWidth;
                                  final fields = <Widget>[
                                    _buildInput(
                                      controller: _businessNameController,
                                      label: 'Business name',
                                    ),
                                    _buildInput(
                                      controller: _contactNameController,
                                      label: 'Contact name',
                                    ),
                                    _buildInput(
                                      controller: _businessPhoneController,
                                      label: 'Phone',
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: null,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9 +()-]'),
                                        ),
                                      ],
                                    ),
                                    _buildInput(
                                      controller: _businessEmailController,
                                      label: 'Email',
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    _buildInput(
                                      controller: _businessAddressController,
                                      label: 'Business address',
                                      minLines: 2,
                                      maxLines: 3,
                                    ),
                                    _buildInput(
                                      controller:
                                          _paymentInstructionsController,
                                      label: 'Payment instructions',
                                      minLines: 2,
                                      maxLines: 3,
                                    ),
                                  ];

                                  return Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      for (final field in fields)
                                        SizedBox(
                                          width: tileWidth,
                                          child: field,
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Use these details for future invoices.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.62,
                                      ),
                                      height: 1.35,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final stacked = constraints.maxWidth < 520;

                                  final actions = <Widget>[
                                    SizedBox(
                                      height: 48,
                                      child: FilledButton.icon(
                                        onPressed: _saveBusinessProfile,
                                        icon: const Icon(Icons.save_outlined),
                                        label: const Text(
                                          'Save business profile',
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF4A7DFF,
                                          ),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _resetBusinessProfile,
                                      child: const Text(
                                        'Reset business profile',
                                      ),
                                    ),
                                  ];

                                  if (stacked) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        actions[0],
                                        const SizedBox(height: 8),
                                        actions[1],
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: actions[0]),
                                      const SizedBox(width: 12),
                                      actions[1],
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                'Bill to',
                                subtitle: 'Editable customer billing details.',
                                icon: Icons.badge_outlined,
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final wide = constraints.maxWidth >= 620;
                                  final tileWidth = wide
                                      ? (constraints.maxWidth - 10) / 2
                                      : constraints.maxWidth;
                                  final fields = <Widget>[
                                    _buildInput(
                                      controller: _customerNameController,
                                      label: 'Customer / company name',
                                    ),
                                    _buildInput(
                                      controller: _customerPhoneController,
                                      label: 'Contact phone',
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: null,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9 +()-]'),
                                        ),
                                      ],
                                    ),
                                    _buildInput(
                                      controller: _billingAddressController,
                                      label: 'Billing address',
                                      minLines: 2,
                                      maxLines: 3,
                                    ),
                                    _buildInput(
                                      controller: _customerEmailController,
                                      label: 'Email optional',
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ];

                                  return Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      for (final field in fields)
                                        SizedBox(
                                          width: tileWidth,
                                          child: field,
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                'Invoice details',
                                subtitle: 'Basic invoice fields stay editable.',
                                icon: Icons.description_outlined,
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final wide = constraints.maxWidth >= 620;
                                  final tileWidth = wide
                                      ? (constraints.maxWidth - 10) / 2
                                      : constraints.maxWidth;
                                  final fields = <Widget>[
                                    _buildInput(
                                      controller: _invoiceNumberController,
                                      label: 'Invoice number',
                                    ),
                                    _buildInput(
                                      controller: _invoiceDateController,
                                      label: 'Invoice date',
                                    ),
                                    _buildInput(
                                      controller: _dueDateController,
                                      label: 'Due date',
                                    ),
                                    _buildInput(
                                      controller: _jobReferenceController,
                                      label: 'Job reference',
                                    ),
                                    _buildInput(
                                      controller: _jobDescriptionController,
                                      label: 'Job description',
                                      minLines: 2,
                                      maxLines: 3,
                                    ),
                                  ];

                                  return Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      for (final field in fields)
                                        SizedBox(
                                          width: tileWidth,
                                          child: field,
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                'Line items',
                                subtitle:
                                    'Keep it simple. Add a few extra rows if needed.',
                                icon: Icons.list_alt_outlined,
                              ),
                              const SizedBox(height: 12),
                              Column(
                                children: [
                                  for (
                                    var i = 0;
                                    i < _lineItems.length;
                                    i++
                                  ) ...[
                                    _buildLineItemRow(_lineItems[i]),
                                    if (i < _lineItems.length - 1)
                                      const SizedBox(height: 10),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Quick extras',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: const [
                                  _InvoiceExtraPreset(
                                    key: 'mileage',
                                    label: 'Mileage',
                                    description: 'Mileage',
                                    quantity: '1',
                                    amount: '0.00',
                                  ),
                                  _InvoiceExtraPreset(
                                    key: 'waiting_time',
                                    label: 'Waiting time',
                                    description: 'Waiting time',
                                    quantity: '1',
                                    amount: '0.00',
                                  ),
                                  _InvoiceExtraPreset(
                                    key: 'stairs',
                                    label: 'Stairs/access charge',
                                    description: 'Stairs/access charge',
                                    quantity: '1',
                                    amount: '0.00',
                                  ),
                                  _InvoiceExtraPreset(
                                    key: 'helper',
                                    label: 'Extra helper',
                                    description: 'Extra helper',
                                    quantity: '1',
                                    amount: '0.00',
                                  ),
                                  _InvoiceExtraPreset(
                                    key: 'collection_delivery',
                                    label: 'Collection/delivery',
                                    description: 'Collection/delivery',
                                    quantity: '1',
                                    amount: '0.00',
                                  ),
                                  _InvoiceExtraPreset(
                                    key: 'custom',
                                    label: 'Custom item',
                                    description: 'Custom item',
                                    quantity: '1',
                                    amount: '0.00',
                                  ),
                                ].map(_buildExtraChip).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                'Mileage / extras',
                                subtitle:
                                    'Mileage can be edited before sending the invoice.',
                                icon: Icons.route_outlined,
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final wide = constraints.maxWidth >= 620;
                                  final tileWidth = wide
                                      ? (constraints.maxWidth - 10) / 2
                                      : constraints.maxWidth;
                                  final fields = <Widget>[
                                    _buildInput(
                                      controller: _estimatedMilesController,
                                      label: 'Estimated miles',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      onChanged: _handleMileageFieldChanged,
                                    ),
                                    _buildInput(
                                      controller: _mileageChargeController,
                                      label: 'Mileage charge',
                                      prefixText: '\u00A3',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      onChanged: _handleMileageFieldChanged,
                                    ),
                                  ];

                                  return Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      for (final field in fields)
                                        SizedBox(
                                          width: tileWidth,
                                          child: field,
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Manual only. No live mileage or GPS tracking.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.62,
                                      ),
                                      height: 1.4,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                'Invoice notes',
                                subtitle:
                                    'A small note can help keep the invoice friendly.',
                                icon: Icons.notes_outlined,
                              ),
                              const SizedBox(height: 12),
                              _buildInput(
                                controller: _invoiceNotesController,
                                label: 'Invoice notes',
                                hint:
                                    'Thank you for your business. Please pay using the details above.',
                                minLines: 3,
                                maxLines: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                'Invoice summary',
                                subtitle:
                                    'Quick totals before opening the full preview.',
                                icon: Icons.receipt_long_outlined,
                              ),
                              const SizedBox(height: 12),
                              _buildInvoiceSummaryCard(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildUpgradeCard(),
                        const SizedBox(height: 12),
                        _buildSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                'Actions',
                                subtitle: 'Preview or save this invoice draft.',
                                icon: Icons.tune_outlined,
                              ),
                              const SizedBox(height: 12),
                              _buildButtonRow(),
                              const SizedBox(height: 8),
                              Text(
                                'Status: $invoiceStatus',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.66,
                                      ),
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
        ],
      ),
    );
  }
}

class _InvoiceLineItemDraft {
  _InvoiceLineItemDraft({
    required String description,
    required String quantity,
    required String amount,
    this.extraKey,
  }) : descriptionController = TextEditingController(text: description),
       quantityController = TextEditingController(text: quantity),
       amountController = TextEditingController(text: amount);

  String? extraKey;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController amountController;

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    amountController.dispose();
  }
}

class _InvoiceExtraPreset {
  const _InvoiceExtraPreset({
    required this.key,
    required this.label,
    required this.description,
    required this.quantity,
    required this.amount,
  });

  final String key;
  final String label;
  final String description;
  final String quantity;
  final String amount;
}
