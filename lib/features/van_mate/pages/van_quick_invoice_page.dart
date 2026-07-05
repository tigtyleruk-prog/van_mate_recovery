import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_business_profile.dart';
import '../models/van_invoice_draft.dart';
import '../services/van_business_profile_storage.dart';
import '../services/van_invoice_number_storage.dart';
import 'driver_customer_reply_mock_page.dart';
import 'van_invoice_preview_page.dart';

Future<void> openVanQuickInvoicePage(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const VanQuickInvoicePage()));
}

class VanQuickInvoicePage extends StatefulWidget {
  const VanQuickInvoicePage({super.key});

  @override
  State<VanQuickInvoicePage> createState() => _VanQuickInvoicePageState();
}

class _VanQuickInvoicePageState extends State<VanQuickInvoicePage> {
  final VanBusinessProfileStorage _profileStorage =
      VanBusinessProfileStorage.instance;
  final VanInvoiceNumberStorage _invoiceNumberStorage =
      VanInvoiceNumberStorage.instance;

  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;
  late final TextEditingController _customerEmailController;
  late final TextEditingController _billingAddressController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _jobDescriptionController;
  late final TextEditingController _completedDateController;
  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _invoiceDateController;
  late final TextEditingController _dueDateController;
  late final TextEditingController _paymentInstructionsController;
  late final TextEditingController _invoiceNotesController;

  final List<_QuickInvoiceItemEditor> _items = <_QuickInvoiceItemEditor>[];

  VanBusinessProfile _businessProfile = const VanBusinessProfile.defaults();
  String? _savedInvoiceKey;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _customerNameController = TextEditingController();
    _customerPhoneController = TextEditingController();
    _customerEmailController = TextEditingController();
    _billingAddressController = TextEditingController();
    _jobTitleController = TextEditingController();
    _jobDescriptionController = TextEditingController();
    _completedDateController = TextEditingController(
      text: formatDate(DateTime.now()),
    );
    _invoiceNumberController = TextEditingController();
    _invoiceDateController = TextEditingController(
      text: formatDate(DateTime.now()),
    );
    _dueDateController = TextEditingController(
      text: VanInvoiceDraft.dueOnReceiptLabel,
    );
    _paymentInstructionsController = TextEditingController(
      text: VanInvoiceDraft.paymentInstructionsFallback,
    );
    _invoiceNotesController = TextEditingController();
    _items.add(_QuickInvoiceItemEditor());
    unawaited(_loadDefaults());
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _billingAddressController.dispose();
    _jobTitleController.dispose();
    _jobDescriptionController.dispose();
    _completedDateController.dispose();
    _invoiceNumberController.dispose();
    _invoiceDateController.dispose();
    _dueDateController.dispose();
    _paymentInstructionsController.dispose();
    _invoiceNotesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    final profile = await _profileStorage.loadCanonicalProfile();
    final invoiceNumber = await _invoiceNumberStorage.peekNextInvoiceNumber();
    if (!mounted) {
      return;
    }
    setState(() {
      _businessProfile = profile;
      _invoiceNumberController.text = invoiceNumber;
      _paymentInstructionsController.text = resolveVanMatePaymentInstructions(
        profile.paymentInstructions,
      );
      _loading = false;
    });
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _addItem() {
    setState(() {
      _items.add(_QuickInvoiceItemEditor());
    });
  }

  void _removeItem(_QuickInvoiceItemEditor item) {
    if (_items.length == 1) {
      item.descriptionController.clear();
      item.amountController.clear();
      setState(() {});
      return;
    }
    setState(() {
      _items.remove(item);
    });
    item.dispose();
  }

  double _parseAmount(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '').trim();
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') {
      return 0;
    }
    return double.tryParse(cleaned) ?? 0;
  }

  double get _totalDue {
    return _items.fold<double>(0, (sum, item) {
      return sum + _parseAmount(item.amountController.text);
    });
  }

  List<VanInvoiceLineItem>? _validatedLineItems() {
    final lineItems = <VanInvoiceLineItem>[];
    var hasAnyDescription = false;

    for (final item in _items) {
      final description = item.descriptionController.text.trim();
      final amount = _parseAmount(item.amountController.text);
      if (description.isEmpty && amount <= 0) {
        continue;
      }
      if (description.isEmpty) {
        _showSnack('Please add at least one invoice item.');
        return null;
      }
      if (amount <= 0) {
        _showSnack('Please enter a valid amount.');
        return null;
      }
      hasAnyDescription = true;
      lineItems.add(
        VanInvoiceLineItem(
          description: description,
          quantity: 1,
          amount: amount,
        ),
      );
    }

    if (!hasAnyDescription || lineItems.isEmpty) {
      _showSnack('Please add at least one invoice item.');
      return null;
    }

    return lineItems;
  }

  VanInvoiceDraft? _buildDraft() {
    final customerName = _customerNameController.text.trim();
    if (customerName.isEmpty) {
      _showSnack('Please enter a customer name.');
      return null;
    }

    final jobTitle = _jobTitleController.text.trim();
    if (jobTitle.isEmpty) {
      _showSnack('Please enter a job title.');
      return null;
    }

    final lineItems = _validatedLineItems();
    if (lineItems == null) {
      return null;
    }

    final invoiceNumber = _invoiceNumberController.text.trim().isEmpty
        ? 'Pending'
        : _invoiceNumberController.text.trim();
    final invoiceDate = _invoiceDateController.text.trim().isEmpty
        ? formatDate(DateTime.now())
        : _invoiceDateController.text.trim();
    final dueDate = _dueDateController.text.trim().isEmpty
        ? VanInvoiceDraft.dueOnReceiptLabel
        : _dueDateController.text.trim();
    final completedDate = _completedDateController.text.trim();
    final defaultDescription = completedDate.isEmpty
        ? 'Invoice for completed $jobTitle work.'
        : 'Invoice for completed $jobTitle work on $completedDate.';

    return VanInvoiceDraft.initial(
      businessProfile: _businessProfile,
      customerName: customerName,
      customerPhone: _customerPhoneController.text.trim(),
      customerEmail: _customerEmailController.text.trim(),
      billingAddress: _billingAddressController.text.trim(),
      invoiceDate: invoiceDate,
      jobReference: jobTitle,
      jobDescription: _jobDescriptionController.text.trim().isEmpty
          ? defaultDescription
          : _jobDescriptionController.text.trim(),
      invoiceNumber: invoiceNumber,
      quoteAmount: 0,
    ).copyWith(
      jobKey: _savedInvoiceKey,
      dueDate: dueDate,
      lineItems: lineItems,
      paymentInstructions: resolveVanMatePaymentInstructions(
        _paymentInstructionsController.text,
      ),
      invoiceNotes: _invoiceNotesController.text.trim(),
      paymentStatus: 'unpaid',
      paidAt: null,
    );
  }

  Future<VanInvoiceDraft?> _saveDraft({bool shareAfterSave = false}) async {
    final draft = _buildDraft();
    if (draft == null) {
      return null;
    }

    final existingKey = _savedInvoiceKey;
    final existingInvoice = existingKey == null
        ? null
        : DriverReplyMockState.instance.invoiceForJob(existingKey);
    final resolvedInvoiceNumber =
        existingInvoice?.invoiceNumber.trim().isNotEmpty == true
        ? existingInvoice!.invoiceNumber.trim()
        : (draft.invoiceNumber.trim().isEmpty ||
                  draft.invoiceNumber == 'Pending'
              ? await _invoiceNumberStorage.peekNextInvoiceNumber()
              : draft.invoiceNumber.trim());
    final invoiceKey =
        existingKey ??
        'manual_invoice_${DateTime.now().millisecondsSinceEpoch}';

    final savedDraft = draft.copyWith(
      jobKey: invoiceKey,
      invoiceNumber: resolvedInvoiceNumber,
      paymentStatus: existingInvoice?.paymentStatus ?? 'unpaid',
      paidAt: existingInvoice?.paidAt,
    );

    DriverReplyMockState.instance.upsertInvoiceForJob(invoiceKey, savedDraft);
    if (existingKey == null) {
      await _invoiceNumberStorage.consumeNextNumber();
    }

    if (!mounted) {
      return savedDraft;
    }

    setState(() {
      _savedInvoiceKey = invoiceKey;
      _invoiceNumberController.text = resolvedInvoiceNumber;
    });

    _showSnack(existingKey == null ? 'Invoice saved.' : 'Invoice updated.');

    if (shareAfterSave) {
      await SharePlus.instance.share(
        ShareParams(
          text: savedDraft.buildInvoiceShareText(),
          subject: 'Invoice $resolvedInvoiceNumber',
        ),
      );
    }

    return savedDraft;
  }

  Future<void> _previewInvoice() async {
    final draft = _buildDraft();
    if (draft == null) {
      return;
    }
    final updated = await openVanInvoicePreviewPage(context, draft);
    if (!mounted || updated == null) {
      return;
    }
    setState(() {
      _invoiceNumberController.text = updated.invoiceNumber;
      _invoiceDateController.text = updated.invoiceDate;
      _dueDateController.text = updated.dueDateLabel;
      _jobTitleController.text = updated.jobReference;
      _jobDescriptionController.text = updated.jobDescription;
      _customerNameController.text = updated.customerName;
      _customerPhoneController.text = updated.customerPhone;
      _customerEmailController.text = updated.customerEmail;
      _billingAddressController.text = updated.billingAddress;
      _paymentInstructionsController.text = updated.paymentInstructions;
      _invoiceNotesController.text = updated.invoiceNotes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Quick Invoice'),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AppTheme.backgroundImage(),
          Container(color: Colors.black.withValues(alpha: 0.34)),
          SafeArea(
            bottom: false,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 24),
                    children: [
                      _QuickInvoiceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quick Invoice',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create a one-off invoice without a booking or quote.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.76),
                                fontSize: 13.2,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _QuickInvoiceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle('Customer details'),
                            const SizedBox(height: 12),
                            _field(_customerNameController, 'Customer name *'),
                            const SizedBox(height: 10),
                            _field(_customerPhoneController, 'Phone optional'),
                            const SizedBox(height: 10),
                            _field(
                              _customerEmailController,
                              'Email optional',
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 10),
                            _field(
                              _billingAddressController,
                              'Address optional',
                              minLines: 2,
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _QuickInvoiceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle('Job details'),
                            const SizedBox(height: 12),
                            _field(_jobTitleController, 'Job title *'),
                            const SizedBox(height: 10),
                            _field(
                              _jobDescriptionController,
                              'Job description optional',
                              minLines: 2,
                              maxLines: 4,
                            ),
                            const SizedBox(height: 10),
                            _field(
                              _completedDateController,
                              'Completed date optional',
                            ),
                            const SizedBox(height: 10),
                            _field(
                              _invoiceNotesController,
                              'Notes optional',
                              minLines: 2,
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _QuickInvoiceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: _SectionTitle('Invoice items'),
                                ),
                                TextButton.icon(
                                  onPressed: _addItem,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add item'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            for (var i = 0; i < _items.length; i++) ...[
                              _QuickInvoiceItemCard(
                                item: _items[i],
                                onChanged: () => setState(() {}),
                                onRemove: () => _removeItem(_items[i]),
                                canRemove: _items.length > 1,
                              ),
                              if (i < _items.length - 1)
                                const SizedBox(height: 10),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              'Total due: ${formatCurrency(_totalDue)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _QuickInvoiceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle('Invoice details'),
                            const SizedBox(height: 12),
                            _field(_invoiceNumberController, 'Invoice number'),
                            const SizedBox(height: 10),
                            _field(_invoiceDateController, 'Invoice date'),
                            const SizedBox(height: 10),
                            _field(_dueDateController, 'Due date'),
                            const SizedBox(height: 10),
                            _field(
                              _paymentInstructionsController,
                              'Payment instructions',
                              minLines: 2,
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _QuickInvoiceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle('Actions'),
                            const SizedBox(height: 12),
                            _ActionButton(
                              label: 'Preview invoice',
                              icon: Icons.visibility_outlined,
                              filled: false,
                              color: const Color(0xFF4A7DFF),
                              onTap: _previewInvoice,
                            ),
                            const SizedBox(height: 10),
                            _ActionButton(
                              label: 'Save invoice',
                              icon: Icons.save_outlined,
                              filled: true,
                              color: const Color(0xFF58D0A4),
                              onTap: () => unawaited(_saveDraft()),
                            ),
                            const SizedBox(height: 10),
                            _ActionButton(
                              label: 'Save and share',
                              icon: Icons.share_outlined,
                              filled: false,
                              color: const Color(0xFF4A7DFF),
                              onTap: () =>
                                  unawaited(_saveDraft(shareAfterSave: true)),
                            ),
                            const SizedBox(height: 10),
                            _ActionButton(
                              label: 'Cancel',
                              icon: Icons.arrow_back_rounded,
                              filled: false,
                              color: Colors.white70,
                              onTap: () => Navigator.of(context).pop(),
                            ),
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
}

class _QuickInvoiceCard extends StatelessWidget {
  const _QuickInvoiceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _QuickInvoiceItemCard extends StatelessWidget {
  const _QuickInvoiceItemCard({
    required this.item,
    required this.onChanged,
    required this.onRemove,
    required this.canRemove,
  });

  final _QuickInvoiceItemEditor item;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          _field(
            item.descriptionController,
            'Item description',
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 10),
          _field(
            item.amountController,
            'Amount',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixText: '£',
            onChanged: (_) => onChanged(),
          ),
          if (canRemove) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _QuickInvoiceItemEditor {
  _QuickInvoiceItemEditor({String description = '', String amount = ''})
    : descriptionController = TextEditingController(text: description),
      amountController = TextEditingController(text: amount);

  final TextEditingController descriptionController;
  final TextEditingController amountController;

  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
  }
}

Widget _field(
  TextEditingController controller,
  String label, {
  int minLines = 1,
  int maxLines = 1,
  TextInputType? keyboardType,
  String? prefixText,
  ValueChanged<String>? onChanged,
}) {
  return TextField(
    controller: controller,
    minLines: minLines,
    maxLines: maxLines,
    keyboardType: keyboardType,
    onChanged: onChanged,
    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
      prefixText: prefixText,
      prefixStyle: const TextStyle(color: Colors.white),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: Color(0xFF4A7DFF), width: 1.4),
      ),
    ),
  );
}
