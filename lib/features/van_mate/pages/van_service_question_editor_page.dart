import 'package:flutter/material.dart';

import '../models/van_custom_job_question.dart';
import '../widgets/van_form_field_styles.dart';

Future<VanCustomJobQuestion?> editVanServiceQuestion(
  BuildContext context, {
  required String serviceId,
  VanCustomJobQuestion? question,
}) {
  return Navigator.of(context).push<VanCustomJobQuestion>(
    MaterialPageRoute<VanCustomJobQuestion>(
      builder: (_) => _VanServiceQuestionEditorPage(
        serviceId: serviceId,
        question: question,
      ),
    ),
  );
}

class _VanServiceQuestionEditorPage extends StatefulWidget {
  const _VanServiceQuestionEditorPage({required this.serviceId, this.question});

  final String serviceId;
  final VanCustomJobQuestion? question;

  @override
  State<_VanServiceQuestionEditorPage> createState() =>
      _VanServiceQuestionEditorPageState();
}

class _VanServiceQuestionEditorPageState
    extends State<_VanServiceQuestionEditorPage> {
  late final TextEditingController _textController;
  late final TextEditingController _helperController;
  late VanCustomQuestionAnswerType _answerType;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.question?.questionText ?? '',
    );
    _helperController = TextEditingController(
      text: widget.question?.helperText ?? '',
    );
    _answerType =
        widget.question?.answerType ?? VanCustomQuestionAnswerType.shortText;
    _active = widget.question?.isActive ?? true;
  }

  @override
  void dispose() {
    _textController.dispose();
    _helperController.dispose();
    super.dispose();
  }

  void _save() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final existing = widget.question;
    final normalizedServiceId = widget.serviceId.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]+'),
      '_',
    );
    Navigator.of(context).pop(
      VanCustomJobQuestion(
        id:
            existing?.id ??
            'service_question_${normalizedServiceId}_${now.microsecondsSinceEpoch}',
        questionText: text,
        helperText: _helperController.text.trim(),
        answerType: _answerType,
        category: existing?.category,
        choiceOptions: existing?.choiceOptions ?? const <String>[],
        isActive: _active,
        isArchived: false,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.question == null ? 'New Question' : 'Edit Question'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _textController,
            decoration: vanMateFieldDecoration(label: 'Question'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _helperController,
            decoration: vanMateFieldDecoration(
              label: 'Helper text',
              hintText: 'Optional',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<VanCustomQuestionAnswerType>(
            initialValue: _answerType,
            decoration: vanMateFieldDecoration(label: 'Answer type'),
            items: [
              for (final type in VanCustomQuestionAnswerType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _answerType = value);
              }
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _active,
            onChanged: (value) => setState(() => _active = value),
            title: const Text('Enabled'),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save question'),
          ),
        ],
      ),
    );
  }
}
