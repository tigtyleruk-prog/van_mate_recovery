import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_business_logo_support.dart';
import '../models/van_business_profile.dart';
import '../models/van_invoice_draft.dart';
import '../services/van_business_profile_storage.dart';
import '../services/van_invoice_number_storage.dart';
import 'driver_customer_reply_mock_page.dart';
import 'van_invoice_preview_page.dart';
import '../widgets/van_form_field_styles.dart';

Future<void> openCreateInvoiceHubPage(
  BuildContext context,
  DriverCustomerReplyMockData reply,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => VanInvoiceHubPage(reply: reply)),
  );
}

class VanInvoiceHubPage extends StatefulWidget {
  const VanInvoiceHubPage({super.key, required this.reply});

  final DriverCustomerReplyMockData reply;

  @override
  State<VanInvoiceHubPage> createState() => _VanInvoiceHubPageState();
}

class _VanInvoiceHubPageState extends State<VanInvoiceHubPage> {
  final VanBusinessProfileStorage _storage = VanBusinessProfileStorage.instance;
  final VanInvoiceNumberStorage _invoiceNumberStorage =
      VanInvoiceNumberStorage.instance;
  VanInvoiceDraft? _draft;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDraft());
  }

  Future<void> _loadDraft() async {
    final profile = await _storage.load();
    final savedInvoice =
        DriverReplyMockState.instance.invoiceForJob(widget.reply.invoiceHistoryKey);
    final draft = savedInvoice ??
        VanInvoiceDraft.initial(
          jobKey: widget.reply.invoiceHistoryKey,
          businessProfile: profile,
          customerName: widget.reply.customerName,
          customerPhone: widget.reply.phoneNumber,
          billingAddress: widget.reply.address,
          invoiceDate: widget.reply.jobDateLabel,
          jobReference: widget.reply.jobTitle,
          jobDescription: widget.reply.notesMessage.trim().isEmpty
              ? '${widget.reply.jobTitle} and delivery job completed.'
              : widget.reply.notesMessage.trim(),
          invoiceNumber: await _invoiceNumberStorage.peekNextInvoiceNumber(),
        ).copyWith(
          lineItems: [
            VanInvoiceLineItem(
              description: widget.reply.jobTitle,
              quantity: 1,
              amount: widget.reply.quoteAmount ?? 0,
            ),
          ],
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _draft = draft;
      _loading = false;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openSection(
    Future<VanInvoiceDraft?> Function() openPage,
  ) async {
    final updated = await openPage();
    if (updated == null || !mounted) {
      return;
    }

    setState(() {
      _draft = updated;
    });
  }

  Future<void> _previewInvoice() async {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    final updated = await openVanInvoicePreviewPage(context, draft);
    if (!mounted || updated == null) {
      return;
    }

    setState(() {
      _draft = updated;
    });
  }

  Future<void> _saveInvoice() async {
    final draft = _draft;
    if (draft == null) {
      return;
    }

    final jobKey = widget.reply.invoiceHistoryKey;
    final existingInvoice = DriverReplyMockState.instance.invoiceForJob(jobKey);
    final resolvedInvoiceNumber = existingInvoice?.invoiceNumber.trim().isNotEmpty == true
        ? existingInvoice!.invoiceNumber.trim()
        : (draft.invoiceNumber.trim().isEmpty
              ? await _invoiceNumberStorage.peekNextInvoiceNumber()
              : draft.invoiceNumber.trim());
    final savedDraft = draft.copyWith(
      invoiceNumber: resolvedInvoiceNumber,
      jobKey: jobKey,
      paymentStatus: existingInvoice?.paymentStatus ?? 'unpaid',
      paidAt: existingInvoice?.paidAt,
    );

    setState(() {
      _draft = savedDraft;
      DriverReplyMockState.instance.upsertInvoiceForJob(jobKey, savedDraft);
      DriverReplyMockState.instance.setInvoiceCreated(true, jobId: jobKey);
    });

    if (existingInvoice == null) {
      await _invoiceNumberStorage.consumeNextNumber();
      _showSnack('Invoice saved.');
    } else {
      _showSnack('Invoice updated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final hasSavedInvoice =
        DriverReplyMockState.instance.invoiceForJob(widget.reply.invoiceHistoryKey) !=
        null;
    final isPaid = draft?.isPaid == true;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            child: _loading || draft == null
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 780),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BackButton(
                              onTap: () => Navigator.of(context).pop(),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Create invoice',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Edit each section separately to keep typing smooth.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.76),
                                    height: 1.45,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            _HubSectionCard(
                              title: 'Job summary',
                              subtitle: 'Invoice for the completed job.',
                              lines: [
                                'Status: ${hasSavedInvoice ? (isPaid ? 'Invoice paid' : 'Invoice saved') : 'Ready to invoice'}',
                                draft.customerName,
                                draft.jobReference,
                                'Invoice no: ${draft.invoiceNumber}',
                                'Due date: ${draft.dueDate}',
                              ],
                              actionLabel: 'Edit job details',
                              onAction: () => _openSection(() async {
                                final result = await Navigator.of(context)
                                    .push<VanInvoiceDraft>(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EditInvoiceJobDetailsPage(
                                              draft: draft,
                                            ),
                                      ),
                                    );
                                return result;
                              }),
                            ),
                            const SizedBox(height: 12),
                            _HubSectionCard(
                              title: 'Business details',
                              subtitle: 'Logo, business name and payment info.',
                              lines: [
                                draft.businessName,
                                draft.hasLogo
                                    ? 'Logo added'
                                    : 'No logo selected',
                                draft.paymentInstructions.trim().isEmpty
                                    ? 'Payment instructions not set'
                                    : 'Payment instructions set',
                              ],
                              actionLabel: 'Edit business details',
                              onAction: () => _openSection(() async {
                                final result = await Navigator.of(context)
                                    .push<VanInvoiceDraft>(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EditInvoiceBusinessDetailsPage(
                                              draft: draft,
                                            ),
                                      ),
                                    );
                                return result;
                              }),
                            ),
                            const SizedBox(height: 12),
                            _HubSectionCard(
                              title: 'Bill to',
                              subtitle: 'Customer billing details.',
                              lines: [
                                draft.customerName,
                                draft.customerPhone.isEmpty
                                    ? 'No customer phone'
                                    : draft.customerPhone,
                                draft.billingAddress,
                              ],
                              actionLabel: 'Edit bill to',
                              onAction: () => _openSection(() async {
                                final result = await Navigator.of(context)
                                    .push<VanInvoiceDraft>(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EditInvoiceBillToPage(draft: draft),
                                      ),
                                    );
                                return result;
                              }),
                            ),
                            const SizedBox(height: 12),
                            _HubSectionCard(
                              title: 'Items & mileage',
                              subtitle: 'Line items, quick extras and mileage.',
                              lines: [
                                '${draft.lineItemCount} line items',
                                'Total due: ${draft.totalDueText}',
                                'Mileage charge: \u00A3${draft.mileageCharge.toStringAsFixed(2)}',
                              ],
                              actionLabel: 'Edit items & mileage',
                              onAction: () => _openSection(() async {
                                final result = await Navigator.of(context)
                                    .push<VanInvoiceDraft>(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EditInvoiceItemsPage(draft: draft),
                                      ),
                                    );
                                return result;
                              }),
                            ),
                            const SizedBox(height: 12),
                            _HubSectionCard(
                              title: 'Notes / payment',
                              subtitle: 'Final invoice note and payment text.',
                              lines: [
                                draft.paymentInstructions.isEmpty
                                    ? 'Payment instructions not set'
                                    : draft.paymentInstructions,
                                draft.invoiceNotes.isEmpty
                                    ? 'No invoice notes'
                                    : draft.invoiceNotes,
                              ],
                              actionLabel: 'Edit notes / payment',
                              onAction: () => _openSection(() async {
                                final result = await Navigator.of(context)
                                    .push<VanInvoiceDraft>(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EditInvoiceNotesPage(draft: draft),
                                      ),
                                    );
                                return result;
                              }),
                            ),
                            const SizedBox(height: 12),
                            _HubSectionCard(
                              title: 'Preview invoice',
                              subtitle: 'Open the final white preview page.',
                              lines: ['Ready to review the latest draft.'],
                              actionLabel: 'Preview invoice',
                              onAction: _previewInvoice,
                              filledAction: true,
                            ),
                            const SizedBox(height: 12),
                            _HubSectionCard(
                              title: 'Status',
                              subtitle: 'Quick overview before saving.',
                              lines: [
                                'Completed',
                                'Quote sent',
                                'Status: ${hasSavedInvoice ? (isPaid ? 'Invoice paid' : 'Invoice saved') : 'Ready to invoice'}',
                                'Total due: ${draft.totalDueText}',
                              ],
                              actionLabel:
                                  hasSavedInvoice ? 'Update invoice' : 'Save invoice',
                              onAction: _saveInvoice,
                              filledAction: true,
                            ),
                          ],
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

class EditInvoiceJobDetailsPage extends StatefulWidget {
  const EditInvoiceJobDetailsPage({super.key, required this.draft});

  final VanInvoiceDraft draft;

  @override
  State<EditInvoiceJobDetailsPage> createState() =>
      _EditInvoiceJobDetailsPageState();
}

class _EditInvoiceJobDetailsPageState extends State<EditInvoiceJobDetailsPage> {
  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _invoiceDateController;
  late final TextEditingController _dueDateController;
  late final TextEditingController _jobReferenceController;
  late final TextEditingController _jobDescriptionController;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _invoiceNumberController = TextEditingController(text: draft.invoiceNumber);
    _invoiceDateController = TextEditingController(text: draft.invoiceDate);
    _dueDateController = TextEditingController(text: draft.dueDate);
    _jobReferenceController = TextEditingController(text: draft.jobReference);
    _jobDescriptionController = TextEditingController(
      text: draft.jobDescription,
    );
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _invoiceDateController.dispose();
    _dueDateController.dispose();
    _jobReferenceController.dispose();
    _jobDescriptionController.dispose();
    super.dispose();
  }

  void _saveAndBack() {
    Navigator.of(context).pop(
      widget.draft.copyWith(
        invoiceNumber: _invoiceNumberController.text.trim(),
        invoiceDate: _invoiceDateController.text.trim(),
        dueDate: _dueDateController.text.trim(),
        jobReference: _jobReferenceController.text.trim(),
        jobDescription: _jobDescriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EditSectionScaffold(
      title: 'Edit job details',
      subtitle:
          'Keep the invoice number and job text separate from the big form.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(_invoiceNumberController, 'Invoice number'),
          const SizedBox(height: 10),
          _field(_invoiceDateController, 'Invoice date'),
          const SizedBox(height: 10),
          _field(_dueDateController, 'Due date'),
          const SizedBox(height: 10),
          _field(_jobReferenceController, 'Job reference'),
          const SizedBox(height: 10),
          _field(
            _jobDescriptionController,
            'Job description',
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          _ActionRow(
            primaryLabel: 'Save & back',
            primaryOnTap: _saveAndBack,
            secondaryLabel: 'Cancel',
            secondaryOnTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class EditInvoiceBusinessDetailsPage extends StatefulWidget {
  const EditInvoiceBusinessDetailsPage({super.key, required this.draft});

  final VanInvoiceDraft draft;

  @override
  State<EditInvoiceBusinessDetailsPage> createState() =>
      _EditInvoiceBusinessDetailsPageState();
}

class _EditInvoiceBusinessDetailsPageState
    extends State<EditInvoiceBusinessDetailsPage> {
  final ImagePicker _imagePicker = ImagePicker();
  final VanBusinessProfileStorage _storage = VanBusinessProfileStorage.instance;
  late final TextEditingController _businessNameController;
  late final TextEditingController _contactNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _paymentInstructionsController;
  String? _selectedLogoPath;
  String? _selectedLogoName;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _businessNameController = TextEditingController(text: draft.businessName);
    _contactNameController = TextEditingController(text: draft.contactName);
    _phoneController = TextEditingController(text: draft.phone);
    _emailController = TextEditingController(text: draft.email);
    _addressController = TextEditingController(text: draft.businessAddress);
    _paymentInstructionsController = TextEditingController(
      text: draft.paymentInstructions,
    );
    _selectedLogoPath = draft.logoPath;
    _selectedLogoName = draft.hasLogo ? 'Saved logo' : null;
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _contactNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _paymentInstructionsController.dispose();
    super.dispose();
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
        _selectedLogoPath = pickedImage.path.trim().isEmpty
            ? null
            : pickedImage.path.trim();
        _selectedLogoName = pickedImage.name;
      });
    } catch (_) {
      if (mounted) {
        _showSnack('Could not pick logo.');
      }
    }
  }

  void _removeLogo() {
    setState(() {
      _selectedLogoPath = null;
      _selectedLogoName = null;
    });
  }

  Future<void> _saveBusinessProfile() async {
    final profile = VanBusinessProfile(
      businessName: _businessNameController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().businessName
          : _businessNameController.text.trim(),
      contactName: _contactNameController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().contactName
          : _contactNameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().phone
          : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().email
          : _emailController.text.trim(),
      businessAddress: _addressController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().businessAddress
          : _addressController.text.trim(),
      paymentInstructions: _paymentInstructionsController.text.trim().isEmpty
          ? const VanBusinessProfile.defaults().paymentInstructions
          : _paymentInstructionsController.text.trim(),
      logoPath: resolveSavedVanBusinessLogoPath(_selectedLogoPath),
    );

    await _storage.save(profile);
    if (mounted) {
      _showSnack('Business profile saved.');
    }
  }

  Future<void> _resetProfile() async {
    await _storage.clear();
    if (!mounted) {
      return;
    }

    const defaults = VanBusinessProfile.defaults();
    setState(() {
      _businessNameController.text = defaults.businessName;
      _contactNameController.text = defaults.contactName;
      _phoneController.text = defaults.phone;
      _emailController.text = defaults.email;
      _addressController.text = defaults.businessAddress;
      _paymentInstructionsController.text = defaults.paymentInstructions;
      _selectedLogoPath = null;
      _selectedLogoName = null;
    });
    _showSnack('Business profile reset.');
  }

  void _saveAndBack() {
    Navigator.of(context).pop(
      widget.draft.copyWith(
        businessName: _businessNameController.text.trim(),
        contactName: _contactNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        businessAddress: _addressController.text.trim(),
        paymentInstructions: _paymentInstructionsController.text.trim(),
        logoPath: resolveSavedVanBusinessLogoPath(_selectedLogoPath),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo = _selectedLogoPath != null;

    return _EditSectionScaffold(
      title: 'Edit business details',
      subtitle: 'Logo and business profile stay isolated here.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LogoPanel(
            hasLogo: hasLogo,
            logoName: _selectedLogoName,
            logoPath: _selectedLogoPath,
            onPick: _pickLogo,
            onRemove: _removeLogo,
          ),
          const SizedBox(height: 12),
          _field(_businessNameController, 'Business name'),
          const SizedBox(height: 10),
          _field(_contactNameController, 'Contact name'),
          const SizedBox(height: 10),
          _field(
            _phoneController,
            'Phone',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: null,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]')),
            ],
          ),
          const SizedBox(height: 10),
          _field(
            _emailController,
            'Email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _field(
            _addressController,
            'Business address',
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 10),
          _field(
            _paymentInstructionsController,
            'Payment instructions',
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          _ActionRow(
            primaryLabel: 'Save business profile',
            primaryOnTap: _saveBusinessProfile,
            secondaryLabel: 'Reset business profile',
            secondaryOnTap: _resetProfile,
            tertiaryLabel: 'Save & back',
            tertiaryOnTap: _saveAndBack,
          ),
        ],
      ),
    );
  }
}

class EditInvoiceBillToPage extends StatefulWidget {
  const EditInvoiceBillToPage({super.key, required this.draft});

  final VanInvoiceDraft draft;

  @override
  State<EditInvoiceBillToPage> createState() => _EditInvoiceBillToPageState();
}

class _EditInvoiceBillToPageState extends State<EditInvoiceBillToPage> {
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;
  late final TextEditingController _billingAddressController;
  late final TextEditingController _customerEmailController;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _customerNameController = TextEditingController(text: draft.customerName);
    _customerPhoneController = TextEditingController(text: draft.customerPhone);
    _billingAddressController = TextEditingController(
      text: draft.billingAddress,
    );
    _customerEmailController = TextEditingController(text: draft.customerEmail);
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _billingAddressController.dispose();
    _customerEmailController.dispose();
    super.dispose();
  }

  void _saveAndBack() {
    Navigator.of(context).pop(
      widget.draft.copyWith(
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        billingAddress: _billingAddressController.text.trim(),
        customerEmail: _customerEmailController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EditSectionScaffold(
      title: 'Edit bill to',
      subtitle: 'This page stays small and fast for customer details.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(_customerNameController, 'Customer / company name'),
          const SizedBox(height: 10),
          _field(
            _customerPhoneController,
            'Contact phone',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: null,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]')),
            ],
          ),
          const SizedBox(height: 10),
          _field(
            _billingAddressController,
            'Billing address',
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 10),
          _field(
            _customerEmailController,
            'Email optional',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _ActionRow(
            primaryLabel: 'Save & back',
            primaryOnTap: _saveAndBack,
            secondaryLabel: 'Cancel',
            secondaryOnTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class EditInvoiceItemsPage extends StatefulWidget {
  const EditInvoiceItemsPage({super.key, required this.draft});

  final VanInvoiceDraft draft;

  @override
  State<EditInvoiceItemsPage> createState() => _EditInvoiceItemsPageState();
}

class _EditInvoiceItemsPageState extends State<EditInvoiceItemsPage> {
  late final TextEditingController _estimatedMilesController;
  late final TextEditingController _mileageChargeController;
  final List<_LineItemEditor> _items = <_LineItemEditor>[];
  final Set<String> _selectedExtras = <String>{};

  @override
  void initState() {
    super.initState();
    _estimatedMilesController = TextEditingController(
      text: widget.draft.estimatedMiles,
    );
    _mileageChargeController = TextEditingController(
      text: widget.draft.mileageCharge == 0
          ? ''
          : widget.draft.mileageCharge.toStringAsFixed(2),
    );

    for (final item in widget.draft.lineItems) {
      _items.add(
        _LineItemEditor(
          description: item.description,
          quantity: item.quantity.toString(),
          amount: item.amount.toStringAsFixed(2),
        ),
      );
    }

    if (_items.isEmpty) {
      _items.add(
        _LineItemEditor(description: 'Line item', quantity: '1', amount: '0'),
      );
    }

    for (final item in _items) {
      if (item.extraKey != null) {
        _selectedExtras.add(item.extraKey!);
      }
    }
  }

  @override
  void dispose() {
    _estimatedMilesController.dispose();
    _mileageChargeController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addExtra(_InvoiceExtraPreset preset) {
    if (_selectedExtras.contains(preset.key)) {
      return;
    }

    setState(() {
      _selectedExtras.add(preset.key);
      _items.add(
        _LineItemEditor(
          description: preset.description,
          quantity: preset.quantity,
          amount: preset.amount,
          extraKey: preset.key,
        ),
      );
    });
  }

  void _removeItem(_LineItemEditor item) {
    if (item.extraKey == null) {
      return;
    }

    setState(() {
      _selectedExtras.remove(item.extraKey);
      _items.remove(item);
    });
    item.dispose();
  }

  int _quantity(String value) {
    final parsed = int.tryParse(value.trim());
    return parsed == null || parsed <= 0 ? 1 : parsed;
  }

  double _amount(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '').trim();
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') {
      return 0;
    }
    return double.tryParse(cleaned) ?? 0;
  }

  double get _lineItemsTotal {
    return _items.fold<double>(
      0,
      (sum, item) =>
          sum +
          (_quantity(item.quantityController.text) *
              _amount(item.amountController.text)),
    );
  }

  double get _mileageCharge => _amount(_mileageChargeController.text);

  double get _totalDue => _lineItemsTotal + _mileageCharge;

  void _saveAndBack() {
    Navigator.of(context).pop(
      widget.draft.copyWith(
        lineItems: [
          for (final item in _items)
            VanInvoiceLineItem(
              description: item.descriptionController.text.trim().isEmpty
                  ? 'Line item'
                  : item.descriptionController.text.trim(),
              quantity: _quantity(item.quantityController.text),
              amount: _amount(item.amountController.text),
            ),
        ],
        estimatedMiles: _estimatedMilesController.text.trim(),
        mileageCharge: _mileageCharge,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EditSectionScaffold(
      title: 'Edit items & mileage',
      subtitle: 'Only the line-item page rebuilds while you type here.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LineItemCard(
                item: item,
                onChanged: () => setState(() {}),
                onRemove: item.extraKey == null
                    ? null
                    : () => _removeItem(item),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Quick extras',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _extraChip(
                const _InvoiceExtraPreset(
                  key: 'mileage',
                  label: 'Mileage',
                  description: 'Mileage',
                  quantity: '1',
                  amount: '0',
                ),
              ),
              _extraChip(
                const _InvoiceExtraPreset(
                  key: 'waiting_time',
                  label: 'Waiting time',
                  description: 'Waiting time',
                  quantity: '1',
                  amount: '0',
                ),
              ),
              _extraChip(
                const _InvoiceExtraPreset(
                  key: 'stairs',
                  label: 'Stairs/access',
                  description: 'Stairs/access charge',
                  quantity: '1',
                  amount: '0',
                ),
              ),
              _extraChip(
                const _InvoiceExtraPreset(
                  key: 'helper',
                  label: 'Extra helper',
                  description: 'Extra helper',
                  quantity: '1',
                  amount: '0',
                ),
              ),
              _extraChip(
                const _InvoiceExtraPreset(
                  key: 'custom',
                  label: 'Custom item',
                  description: 'Custom item',
                  quantity: '1',
                  amount: '0',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _field(
            _estimatedMilesController,
            'Estimated miles',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 10),
          _field(
            _mileageChargeController,
            'Mileage charge',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixText: '\u00A3',
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
          _SummaryStrip(
            totalDueText: '\u00A3${_totalDue.toStringAsFixed(2)}',
            lineCount: _items.length,
            mileageText: '\u00A3${_mileageCharge.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 16),
          _ActionRow(
            primaryLabel: 'Save & back',
            primaryOnTap: _saveAndBack,
            secondaryLabel: 'Cancel',
            secondaryOnTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _extraChip(_InvoiceExtraPreset preset) {
    final selected = _selectedExtras.contains(preset.key);
    return ChoiceChip(
      selected: selected,
      label: Text(preset.label),
      onSelected: selected ? null : (_) => _addExtra(preset),
      selectedColor: const Color(0xFF4A7DFF).withValues(alpha: 0.26),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.82),
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
    );
  }
}

class EditInvoiceNotesPage extends StatefulWidget {
  const EditInvoiceNotesPage({super.key, required this.draft});

  final VanInvoiceDraft draft;

  @override
  State<EditInvoiceNotesPage> createState() => _EditInvoiceNotesPageState();
}

class _EditInvoiceNotesPageState extends State<EditInvoiceNotesPage> {
  late final TextEditingController _paymentInstructionsController;
  late final TextEditingController _invoiceNotesController;

  @override
  void initState() {
    super.initState();
    _paymentInstructionsController = TextEditingController(
      text: widget.draft.paymentInstructions,
    );
    _invoiceNotesController = TextEditingController(
      text: widget.draft.invoiceNotes,
    );
  }

  @override
  void dispose() {
    _paymentInstructionsController.dispose();
    _invoiceNotesController.dispose();
    super.dispose();
  }

  void _saveAndBack() {
    Navigator.of(context).pop(
      widget.draft.copyWith(
        paymentInstructions: _paymentInstructionsController.text.trim(),
        invoiceNotes: _invoiceNotesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EditSectionScaffold(
      title: 'Edit notes / payment',
      subtitle: 'Keep the final notes separate from the bigger editing pages.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            _paymentInstructionsController,
            'Payment instructions',
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 10),
          _field(
            _invoiceNotesController,
            'Invoice notes',
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          _ActionRow(
            primaryLabel: 'Save & back',
            primaryOnTap: _saveAndBack,
            secondaryLabel: 'Cancel',
            secondaryOnTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _EditSectionScaffold extends StatelessWidget {
  const _EditSectionScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF0E1622),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.32)),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                28 +
                    MediaQuery.viewPaddingOf(context).bottom +
                    MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _ShellCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                        ),
                        const SizedBox(height: 16),
                        child,
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

class _ShellCard extends StatelessWidget {
  const _ShellCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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
          ),
          child: child,
        ),
      ),
    );
  }
}

class _HubSectionCard extends StatelessWidget {
  const _HubSectionCard({
    required this.title,
    required this.subtitle,
    required this.lines,
    required this.actionLabel,
    required this.onAction,
    this.filledAction = false,
  });

  final String title;
  final String subtitle;
  final List<String> lines;
  final String actionLabel;
  final VoidCallback onAction;
  final bool filledAction;

  @override
  Widget build(BuildContext context) {
    return _ShellCard(
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
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 12),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: filledAction
                ? FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4A7DFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(actionLabel),
                  )
                : OutlinedButton(
                    onPressed: onAction,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(actionLabel),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 19,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.primaryLabel,
    required this.primaryOnTap,
    required this.secondaryLabel,
    required this.secondaryOnTap,
    this.tertiaryLabel,
    this.tertiaryOnTap,
  });

  final String primaryLabel;
  final VoidCallback primaryOnTap;
  final String secondaryLabel;
  final VoidCallback secondaryOnTap;
  final String? tertiaryLabel;
  final VoidCallback? tertiaryOnTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 560 || tertiaryLabel != null;

        final primaryButton = SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: primaryOnTap,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4A7DFF),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(primaryLabel, maxLines: 1),
            ),
          ),
        );

        final secondaryButton = SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: secondaryOnTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(secondaryLabel, maxLines: 1),
            ),
          ),
        );

        final tertiaryButton = tertiaryLabel == null || tertiaryOnTap == null
            ? null
            : SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: tertiaryOnTap,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(tertiaryLabel!, maxLines: 1),
                  ),
                ),
              );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primaryButton,
              const SizedBox(height: 10),
              secondaryButton,
              if (tertiaryButton != null) ...[
                const SizedBox(height: 10),
                tertiaryButton,
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: primaryButton),
            const SizedBox(width: 10),
            Expanded(child: secondaryButton),
          ],
        );
      },
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.totalDueText,
    required this.lineCount,
    required this.mileageText,
  });

  final String totalDueText;
  final int lineCount;
  final String mileageText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _infoTile('Total due', totalDueText)),
        const SizedBox(width: 10),
        Expanded(child: _infoTile('Items', lineCount.toString())),
        const SizedBox(width: 10),
        Expanded(child: _infoTile('Mileage', mileageText)),
      ],
    );
  }

  Widget _infoTile(String label, String value) {
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
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _field(
  TextEditingController controller,
  String label, {
  String? hint,
  int minLines = 1,
  int maxLines = 1,
  TextInputType? keyboardType,
  TextInputAction? textInputAction,
  Iterable<String>? autofillHints,
  List<TextInputFormatter>? inputFormatters,
  String? prefixText,
  VoidCallback? onChanged,
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
      labelOpacity: 0.68,
      hintOpacity: 0.50,
    ),
  );
}

class _LogoPanel extends StatelessWidget {
  const _LogoPanel({
    required this.hasLogo,
    required this.logoName,
    required this.logoPath,
    required this.onPick,
    required this.onRemove,
  });

  final bool hasLogo;
  final String? logoName;
  final String? logoPath;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 72,
              height: 72,
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.08),
                child: buildVanBusinessLogoPreview(logoPath),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLogo
                      ? (logoName?.isNotEmpty == true
                            ? 'Selected: $logoName'
                            : 'Logo selected')
                      : 'Add your logo to brand the invoice.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
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
                        onPressed: onPick,
                        icon: Icon(
                          hasLogo
                              ? Icons.swap_horiz_outlined
                              : Icons.add_photo_alternate_outlined,
                        ),
                        label: Text(hasLogo ? 'Change logo' : 'Add logo'),
                      ),
                    ),
                    if (hasLogo)
                      SizedBox(
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: onRemove,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove logo'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Logo is saved locally with your profile.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    height: 1.35,
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

class _LineItemEditor {
  _LineItemEditor({
    required String description,
    required String quantity,
    required String amount,
    this.extraKey,
  }) : descriptionController = TextEditingController(text: description),
       quantityController = TextEditingController(text: quantity),
       amountController = TextEditingController(text: amount);

  final String? extraKey;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController amountController;

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    amountController.dispose();
  }
}

class _LineItemCard extends StatelessWidget {
  const _LineItemCard({
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final _LineItemEditor item;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.of(context).size.width < 520;
    final controls = <Widget>[
      Expanded(
        flex: 3,
        child: _field(
          item.descriptionController,
          'Description',
          hint: 'Line item description',
        ),
      ),
      if (!stacked) const SizedBox(width: 10),
      SizedBox(
        width: stacked ? double.infinity : 82,
        child: _field(
          item.quantityController,
          'Qty',
          keyboardType: TextInputType.number,
          onChanged: onChanged,
        ),
      ),
      if (!stacked) const SizedBox(width: 10),
      SizedBox(
        width: stacked ? double.infinity : 110,
        child: _field(
          item.amountController,
          'Amount',
          prefixText: '\u00A3',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
        ),
      ),
      if (!stacked && onRemove != null) ...[
        const SizedBox(width: 10),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline, color: Colors.white),
        ),
      ],
    ];

    final stackedControls = <Widget>[
      _field(
        item.descriptionController,
        'Description',
        hint: 'Line item description',
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _field(
              item.quantityController,
              'Qty',
              keyboardType: TextInputType.number,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _field(
              item.amountController,
              'Amount',
              prefixText: '\u00A3',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: onChanged,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 10),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, color: Colors.white),
            ),
          ],
        ],
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stacked) ...stackedControls else Row(children: controls),
          const SizedBox(height: 10),
          Text(
            'Line total: \u00A3${(_quantity(item.quantityController.text) * _amount(item.amountController.text)).toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  int _quantity(String value) {
    final parsed = int.tryParse(value.trim());
    return parsed == null || parsed <= 0 ? 1 : parsed;
  }

  double _amount(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '').trim();
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') {
      return 0;
    }
    return double.tryParse(cleaned) ?? 0;
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
