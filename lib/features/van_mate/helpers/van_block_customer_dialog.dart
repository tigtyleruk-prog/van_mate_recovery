import 'package:flutter/material.dart';

class VanBlockCustomerDialogResult {
  const VanBlockCustomerDialogResult({
    required this.reason,
    required this.note,
  });

  final String reason;
  final String note;
}

Future<VanBlockCustomerDialogResult?> showVanBlockCustomerDialog(
  BuildContext context, {
  String initialReason = 'Other',
  String initialNote = '',
}) {
  return showDialog<VanBlockCustomerDialogResult>(
    context: context,
    builder: (dialogContext) => _VanBlockCustomerDialog(
      initialReason: initialReason,
      initialNote: initialNote,
    ),
  );
}

class _VanBlockCustomerDialog extends StatefulWidget {
  const _VanBlockCustomerDialog({
    required this.initialReason,
    required this.initialNote,
  });

  final String initialReason;
  final String initialNote;

  @override
  State<_VanBlockCustomerDialog> createState() =>
      _VanBlockCustomerDialogState();
}

class _VanBlockCustomerDialogState extends State<_VanBlockCustomerDialog> {
  static const List<String> _reasons = <String>[
    'Non-payment',
    'Abusive',
    'No-show',
    'Time-waster',
    'Cancelled too late',
    'Other',
  ];

  late String _selectedReason;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _selectedReason = _reasons.contains(widget.initialReason)
        ? widget.initialReason
        : 'Other';
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF142031),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Block customer?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This will mark them as blocked and warn you if they contact you again.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedReason,
            dropdownColor: const Color(0xFF142031),
            decoration: const InputDecoration(
              labelText: 'Reason',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(color: Colors.white),
            items: _reasons
                .map(
                  (reason) => DropdownMenuItem<String>(
                    value: reason,
                    child: Text(reason),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedReason = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Add a note',
              hintText: 'Didn\'t pay invoice after reminders.',
              labelStyle: TextStyle(color: Colors.white70),
              hintStyle: TextStyle(color: Colors.white38),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              VanBlockCustomerDialogResult(
                reason: _selectedReason,
                note: _noteController.text.trim(),
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD24C4C),
            foregroundColor: Colors.white,
          ),
          child: const Text('Block customer'),
        ),
      ],
    );
  }
}
