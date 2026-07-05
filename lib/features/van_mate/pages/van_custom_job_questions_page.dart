import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../helpers/app_theme.dart';
import '../helpers/van_text_formatters.dart';
import '../models/van_custom_job_question.dart';
import '../models/van_default_new_job_question_set.dart';
import '../models/van_prefilled_job_questions.dart';
import '../models/van_question_template.dart';
import '../services/van_custom_job_questions_storage.dart';
import '../services/van_default_new_job_questions_storage.dart';
import '../services/van_question_templates_storage.dart';
import '../widgets/van_back_business_hub_buttons.dart';
import '../widgets/van_form_field_styles.dart';

String _sanitizeQuestionInput(String? value) {
  return sanitizeVanText(value).trim().replaceAll(RegExp(r'\s+'), ' ');
}

Future<void> openVanCustomJobQuestionsPage(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const VanCustomJobQuestionsPage()),
  );
}

Future<Set<String>?> pickVanCustomJobQuestionIds(
  BuildContext context, {
  Set<String> initialSelectedQuestionIds = const <String>{},
}) {
  return Navigator.of(context).push<Set<String>>(
    MaterialPageRoute<Set<String>>(
      builder: (_) => VanCustomJobQuestionsPage(
        selectionMode: true,
        initialSelectedQuestionIds: initialSelectedQuestionIds,
      ),
    ),
  );
}

class VanCustomJobQuestionsPage extends StatefulWidget {
  const VanCustomJobQuestionsPage({
    super.key,
    this.selectionMode = false,
    this.initialSelectedQuestionIds = const <String>{},
  });

  final bool selectionMode;
  final Set<String> initialSelectedQuestionIds;

  @override
  State<VanCustomJobQuestionsPage> createState() =>
      _VanCustomJobQuestionsPageState();
}

class _VanCustomJobQuestionsPageState extends State<VanCustomJobQuestionsPage> {
  final VanCustomJobQuestionsStorage _questionStorage =
      VanCustomJobQuestionsStorage.instance;
  final VanDefaultNewJobQuestionsStorage _defaultQuestionStorage =
      VanDefaultNewJobQuestionsStorage.instance;

  List<VanCustomJobQuestion> _customQuestions = <VanCustomJobQuestion>[];
  final List<TextEditingController> _packControllers =
      <TextEditingController>[];
  bool _loading = true;
  bool _savingDefaultPack = false;
  final Set<String> _selectedLibraryQuestionIds = <String>{};
  final Set<VanCustomQuestionCategory> _expandedLibraryCategories =
      <VanCustomQuestionCategory>{};
  VanDefaultNewJobQuestionSet? _loadedDefaultSet;

  @override
  void initState() {
    super.initState();
    _questionStorage.addListener(_handleStorageChange);
    _expandedLibraryCategories.addAll(<VanCustomQuestionCategory>[
      VanCustomQuestionCategory.access,
      VanCustomQuestionCategory.parking,
      VanCustomQuestionCategory.loading,
    ]);
    if (widget.selectionMode) {
      _selectedLibraryQuestionIds.addAll(widget.initialSelectedQuestionIds);
    }
    unawaited(_loadData());
  }

  @override
  void dispose() {
    _questionStorage.removeListener(_handleStorageChange);
    for (final controller in _packControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleStorageChange() {
    unawaited(_loadData(showLoader: false, reloadDefaultPack: false));
  }

  Future<void> _loadData({
    bool showLoader = true,
    bool reloadDefaultPack = true,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
      });
    }

    debugPrint(
      '[CustomJobQuestionsPage] load start selectionMode=${widget.selectionMode}',
    );
    var loadedQuestions = <VanCustomJobQuestion>[];
    try {
      loadedQuestions = await _questionStorage.loadAll();
      debugPrint(
        '[CustomJobQuestionsPage] local questions loaded count=${loadedQuestions.length}',
      );
      await _questionStorage.loadFromCloud();
      loadedQuestions = await _questionStorage.loadAll();
      debugPrint(
        '[CustomJobQuestionsPage] hydrated questions loaded count=${loadedQuestions.length}',
      );
      if (!widget.selectionMode && reloadDefaultPack) {
        var loadedSet = await _defaultQuestionStorage.load();
        await _defaultQuestionStorage.loadFromCloud();
        loadedSet = await _defaultQuestionStorage.load();
        _setPackQuestions(loadedSet?.questions ?? const <String>[]);
        _loadedDefaultSet = loadedSet;
      }
    } catch (error) {
      debugPrint('[CustomJobQuestionsPage] load error error=$error');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _customQuestions = loadedQuestions;
      _loading = false;
      _selectedLibraryQuestionIds.removeWhere((id) => !_questionIdExists(id));
    });
  }

  bool _questionIdExists(String id) {
    if (VanPrefilledJobQuestions.findById(id) != null) {
      return true;
    }
    return _customQuestions.any((question) => question.id == id);
  }

  List<VanCustomJobQuestion> get _activeCustomQuestions {
    return _customQuestions
        .where((question) => question.isActive && !question.isArchived)
        .toList(growable: false);
  }

  List<VanCustomJobQuestion> get _savedPackQuestions {
    final questions = <VanCustomJobQuestion>[];
    final now = DateTime.now();
    for (final text in _cleanedPackQuestions()) {
      final normalizedText = _sanitizeQuestionInput(text).toLowerCase();
      VanCustomJobQuestion? matched;
      for (final question in VanPrefilledJobQuestions.all) {
        if (_sanitizeQuestionInput(question.questionText).toLowerCase() ==
            normalizedText) {
          matched = question;
          break;
        }
      }
      if (matched == null) {
        for (final question in _activeCustomQuestions) {
          if (_sanitizeQuestionInput(question.questionText).toLowerCase() ==
              normalizedText) {
            matched = question;
            break;
          }
        }
      }
      questions.add(
        matched ??
            VanCustomJobQuestion(
              id:
                  'saved_pack_${text.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "_")}',
              questionText: text,
              helperText: '',
              answerType: VanCustomQuestionAnswerType.shortText,
              category: VanCustomQuestionCategory.other,
              choiceOptions: const <String>[],
              isActive: true,
              isArchived: false,
              createdAt: now,
              updatedAt: now,
            ),
      );
    }
    return questions;
  }

  void _setPackQuestions(List<String> questions) {
    for (final controller in _packControllers) {
      controller.dispose();
    }
    _packControllers
      ..clear()
      ..addAll(
        questions.map(
          (question) =>
              TextEditingController(text: sanitizeVanText(question).trim()),
        ),
      );
  }

  List<String> _cleanedPackQuestions() {
    final questions = <String>[];
    final seen = <String>{};
    for (final controller in _packControllers) {
      final cleaned = _sanitizeQuestionInput(controller.text);
      if (cleaned.isEmpty) {
        continue;
      }
      final normalized = cleaned.toLowerCase();
      if (seen.add(normalized)) {
        questions.add(cleaned);
      }
    }
    return questions;
  }

  bool _savedPackContainsText(String questionText) {
    final normalized = _sanitizeQuestionInput(questionText).toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    for (final controller in _packControllers) {
      if (_sanitizeQuestionInput(controller.text).toLowerCase() == normalized) {
        return true;
      }
    }
    return false;
  }

  void _appendQuestionToPack(String questionText) {
    final cleaned = _sanitizeQuestionInput(questionText);
    if (cleaned.isEmpty) {
      return;
    }

    if (_savedPackContainsText(cleaned)) {
      return;
    }

    setState(() {
      _packControllers.add(TextEditingController(text: cleaned));
    });
  }

  void _removeQuestionFromPack(String questionText) {
    final normalized = _sanitizeQuestionInput(questionText).toLowerCase();
    if (normalized.isEmpty) {
      return;
    }

    setState(() {
      for (var i = _packControllers.length - 1; i >= 0; i--) {
        if (_sanitizeQuestionInput(_packControllers[i].text).toLowerCase() ==
            normalized) {
          _packControllers[i].dispose();
          _packControllers.removeAt(i);
        }
      }
    });
  }

  void _toggleQuestionInSavedPack(VanCustomJobQuestion question, bool value) {
    if (value) {
      _appendQuestionToPack(question.questionText);
      return;
    }
    _removeQuestionFromPack(question.questionText);
  }

  void _applyStarterSetToPack() {
    setState(() {
      _setPackQuestions(VanDefaultNewJobQuestionSet.starterQuestions);
    });
  }

  Future<void> _saveDefaultPack() async {
    if (_savingDefaultPack) {
      return;
    }

    final questions = _cleanedPackQuestions();
    final now = DateTime.now();
    final set = VanDefaultNewJobQuestionSet(
      id: VanDefaultNewJobQuestionSet.defaultId,
      title: VanDefaultNewJobQuestionSet.defaultTitle,
      questions: List<String>.unmodifiable(questions),
      isDefaultForNewJob: true,
      createdAt: _loadedDefaultSet?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() {
      _savingDefaultPack = true;
    });

    try {
      await _defaultQuestionStorage.save(set);
      if (!mounted) {
        return;
      }
      setState(() {
        _loadedDefaultSet = set;
        _savingDefaultPack = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default New Job questions saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savingDefaultPack = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save questions.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openQuestionEditor([VanCustomJobQuestion? question]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => VanCustomQuestionEditorPage(question: question),
      ),
    );
    if (changed == true) {
      await _loadData(showLoader: false);
    }
  }

  void _toggleLibrarySelection(String id, bool value) {
    setState(() {
      if (value) {
        _selectedLibraryQuestionIds.add(id);
      } else {
        _selectedLibraryQuestionIds.remove(id);
      }
    });
  }

  Widget _buildHeaderContent() {
    if (!widget.selectionMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Custom Job Questions',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          _StatusChip(
            label: '${_cleanedPackQuestions().length} saved',
            color: const Color(0xFF4A7DFF),
          ),
          const SizedBox(height: 10),
          Text(
            'Choose the questions you want attached to new job requests.',
            style: TextStyle(
              fontSize: 13.2,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.76),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.selectionMode ? 'Select Questions' : 'Custom Job Questions',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.0,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 10),
        _StatusChip(
          label: '${_selectedLibraryQuestionIds.length} selected',
          color: const Color(0xFF4A7DFF),
        ),
        const SizedBox(height: 10),
        Text(
          'Tick questions to link to this service.',
          style: TextStyle(
            fontSize: 13.2,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.76),
          ),
        ),
      ],
    );
  }

  Widget _buildLibrarySection() {
    if (!widget.selectionMode) {
      return Column(
        children: [
          _buildSavedPackSection(),
          const SizedBox(height: 12),
          for (final category in VanCustomQuestionCategory.values)
            ..._buildSavedPackCategoryCards(category),
          const SizedBox(height: 12),
          _buildSavedPackCustomQuestionsCard(),
          const SizedBox(height: 12),
          _buildSavedPackActionsCard(),
        ],
      );
    }

    return Column(
      children: [
        for (final category in VanCustomQuestionCategory.values)
          ..._buildLibraryCategoryCards(category),
        const SizedBox(height: 10),
        _buildMyQuestionsSelectionCard(),
      ],
    );
  }

  List<Widget> _buildLibraryCategoryCards(VanCustomQuestionCategory category) {
    final items = VanPrefilledJobQuestions.byCategory(category);
    if (items.isEmpty) {
      return const <Widget>[];
    }
    final expanded = _expandedLibraryCategories.contains(category);

    return <Widget>[
      _GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            maintainState: true,
            initiallyExpanded: expanded,
            onExpansionChanged: (value) {
              setState(() {
                if (value) {
                  _expandedLibraryCategories.add(category);
                } else {
                  _expandedLibraryCategories.remove(category);
                }
              });
            },
            title: Text(
              category.label,
              style: const TextStyle(
                fontSize: 15.8,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              'Suggested',
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.white.withValues(alpha: 0.66),
                fontWeight: FontWeight.w600,
              ),
            ),
            iconColor: Colors.white.withValues(alpha: 0.72),
            collapsedIconColor: Colors.white.withValues(alpha: 0.72),
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _QuestionTickRow(
                  question: items[i],
                  value: _selectedLibraryQuestionIds.contains(items[i].id),
                  onChanged: (value) =>
                      _toggleLibrarySelection(items[i].id, value),
                ),
                if (i < items.length - 1)
                  Divider(
                    color: Colors.white.withValues(alpha: 0.10),
                    height: 1,
                  ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
    ];
  }

  Widget _buildMyQuestionsSelectionCard() {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Questions',
            style: TextStyle(
              fontSize: 15.8,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Your custom questions',
            style: TextStyle(
              fontSize: 12.0,
              color: Colors.white.withValues(alpha: 0.66),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (_activeCustomQuestions.isEmpty)
            Text(
              'No custom questions yet. Tap + Add my question below.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            for (var i = 0; i < _activeCustomQuestions.length; i++) ...[
              _QuestionTickRow(
                question: _activeCustomQuestions[i],
                value: _selectedLibraryQuestionIds.contains(
                  _activeCustomQuestions[i].id,
                ),
                onChanged: (value) => _toggleLibrarySelection(
                  _activeCustomQuestions[i].id,
                  value,
                ),
              ),
              if (i < _activeCustomQuestions.length - 1)
                Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildSavedPackSection() {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Saved question pack',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
              _StatusChip(
                label: '${_cleanedPackQuestions().length} total',
                color: const Color(0xFF4A7DFF),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This is the default question pack New Job will use.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (_savedPackQuestions.isEmpty)
            Text(
              'No questions saved yet. Tick questions below or use the starter set.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            for (var i = 0; i < _savedPackQuestions.length; i++) ...[
              _QuestionTickRow(
                question: _savedPackQuestions[i],
                value: true,
                onChanged: (value) {
                  if (!value) {
                    _removeQuestionFromPack(_savedPackQuestions[i].questionText);
                  }
                },
              ),
              if (i < _savedPackQuestions.length - 1)
                Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),
            ],
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _applyStarterSetToPack,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Use starter set'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSavedPackCategoryCards(VanCustomQuestionCategory category) {
    final items = VanPrefilledJobQuestions.byCategory(category);
    if (items.isEmpty) {
      return const <Widget>[];
    }
    final expanded = _expandedLibraryCategories.contains(category);

    return <Widget>[
      _GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            maintainState: true,
            initiallyExpanded: expanded,
            onExpansionChanged: (value) {
              setState(() {
                if (value) {
                  _expandedLibraryCategories.add(category);
                } else {
                  _expandedLibraryCategories.remove(category);
                }
              });
            },
            title: Text(
              category.label,
              style: const TextStyle(
                fontSize: 15.8,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              'Suggested',
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.white.withValues(alpha: 0.66),
                fontWeight: FontWeight.w600,
              ),
            ),
            iconColor: Colors.white.withValues(alpha: 0.72),
            collapsedIconColor: Colors.white.withValues(alpha: 0.72),
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _QuestionTickRow(
                  question: items[i],
                  value: _savedPackContainsText(items[i].questionText),
                  onChanged: (value) =>
                      _toggleQuestionInSavedPack(items[i], value),
                ),
                if (i < items.length - 1)
                  Divider(
                    color: Colors.white.withValues(alpha: 0.10),
                    height: 1,
                  ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
    ];
  }

  Widget _buildSavedPackCustomQuestionsCard() {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Questions',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your reusable custom questions',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (_activeCustomQuestions.isEmpty)
            Text(
              'No reusable questions yet. Add one below, then tick it to include it.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            for (var i = 0; i < _activeCustomQuestions.length; i++) ...[
              _QuestionTickRow(
                question: _activeCustomQuestions[i],
                value: _savedPackContainsText(
                  _activeCustomQuestions[i].questionText,
                ),
                onChanged: (value) =>
                    _toggleQuestionInSavedPack(_activeCustomQuestions[i], value),
              ),
              if (i < _activeCustomQuestions.length - 1)
                Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),
            ],
        ],
      ),
    );
  }

  Widget _buildSavedPackActionsCard() {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 390;
          final addQuestionButton = SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => _openQuestionEditor(),
              child: const Text('Add reusable question'),
            ),
          );
          final saveButton = SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _savingDefaultPack ? null : _saveDefaultPack,
              icon: _savingDefaultPack
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save questions'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A7DFF),
                foregroundColor: Colors.white,
              ),
            ),
          );

          return stacked
              ? Column(
                  children: [
                    SizedBox(width: double.infinity, child: addQuestionButton),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: saveButton),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: addQuestionButton),
                    const SizedBox(width: 10),
                    Expanded(child: saveButton),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildBottomActionSection() {
    if (!widget.selectionMode) {
      return const SizedBox.shrink();
    }

    final selectedCount = _selectedLibraryQuestionIds.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackButtons = constraints.maxWidth < 390;
        final addQuestionButton = SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: () => _openQuestionEditor(),
            child: const Text('+ Add my question', overflow: TextOverflow.fade),
          ),
        );
        final useSelectedButton = SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: selectedCount == 0
                ? null
                : widget.selectionMode
                ? () => Navigator.of(
                    context,
                  ).pop(Set<String>.from(_selectedLibraryQuestionIds))
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Open this from Service Detail to link selected questions.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
            style: FilledButton.styleFrom(
              disabledForegroundColor: Colors.white.withValues(alpha: 0.70),
              disabledBackgroundColor: const Color(
                0xFF4A7DFF,
              ).withValues(alpha: 0.34),
            ),
            child: Text(
              'Use selected ($selectedCount)',
              overflow: TextOverflow.fade,
            ),
          ),
        );

        return _GlassCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: stackButtons
              ? Column(
                  children: [
                    SizedBox(width: double.infinity, child: addQuestionButton),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: useSelectedButton),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: addQuestionButton),
                    const SizedBox(width: 10),
                    Expanded(child: useSelectedButton),
                  ],
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewPadding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.selectionMode ? 'Select Questions' : 'Custom Job Questions',
        ),
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
            child: _loading
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
                      bottomInset + 20,
                    ),
                    children: [
                      _buildHeaderContent(),
                      const SizedBox(height: 12),
                      _buildLibrarySection(),
                      const SizedBox(height: 12),
                      _buildBottomActionSection(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class VanCustomQuestionEditorPage extends StatefulWidget {
  const VanCustomQuestionEditorPage({super.key, this.question});

  final VanCustomJobQuestion? question;

  @override
  State<VanCustomQuestionEditorPage> createState() =>
      _VanCustomQuestionEditorPageState();
}

class _VanCustomQuestionEditorPageState
    extends State<VanCustomQuestionEditorPage> {
  final VanCustomJobQuestionsStorage _storage =
      VanCustomJobQuestionsStorage.instance;
  late final TextEditingController _questionController;
  late final TextEditingController _helperTextController;
  late final TextEditingController _choiceOptionsController;
  late VanCustomQuestionAnswerType _answerType;
  VanCustomQuestionCategory? _category;
  late bool _isActive;
  bool _saving = false;

  bool get _isEditing => widget.question != null;

  @override
  void initState() {
    super.initState();
    final question = widget.question;
    _questionController = TextEditingController(
      text: question?.questionText ?? '',
    );
    _helperTextController = TextEditingController(
      text: question?.helperText ?? '',
    );
    _choiceOptionsController = TextEditingController(
      text: question?.choiceOptions.join(', ') ?? '',
    );
    _answerType = question?.answerType ?? VanCustomQuestionAnswerType.shortText;
    _category = question?.category;
    _isActive = question?.isActive ?? true;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _helperTextController.dispose();
    _choiceOptionsController.dispose();
    super.dispose();
  }

  List<String> _parseChoices(String raw) {
    return raw
        .split(',')
        .map((item) => _sanitizeQuestionInput(item))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _saveQuestion() async {
    if (_saving) {
      return;
    }

    final questionText = _sanitizeQuestionInput(_questionController.text);
    if (questionText.isEmpty) {
      _showSnack('Please enter a question.');
      return;
    }

    final helperText = _sanitizeQuestionInput(_helperTextController.text);
    final choices = _parseChoices(_choiceOptionsController.text);
    if (_answerType == VanCustomQuestionAnswerType.multipleChoice &&
        choices.length < 2) {
      _showSnack('Please add at least two choices.');
      return;
    }

    final now = DateTime.now();
    final existing = widget.question;
    final next = VanCustomJobQuestion(
      id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
      questionText: questionText,
      helperText: helperText,
      answerType: _answerType,
      category: _category,
      choiceOptions: _answerType == VanCustomQuestionAnswerType.multipleChoice
          ? List<String>.unmodifiable(choices)
          : const <String>[],
      isActive: _isActive,
      isArchived: existing?.isArchived ?? false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() {
      _saving = true;
    });

    try {
      await _storage.upsert(next);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      _showSnack('Could not save question.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final title = _isEditing ? 'Edit Question' : 'Add Question';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title),
        leadingWidth: 96,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: VanBackBusinessHubButtons(
            onBack: () => Navigator.of(context).pop(false),
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
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create reusable questions for your services.',
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
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Question Details',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _EditorField(
                        controller: _questionController,
                        label: 'Question text',
                        hint: 'Type your question',
                      ),
                      const SizedBox(height: 12),
                      _EditorField(
                        controller: _helperTextController,
                        label: 'Helper text (optional)',
                        hint: 'Optional guidance for customer',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<VanCustomQuestionAnswerType>(
                        initialValue: _answerType,
                        dropdownColor: const Color(0xFF131B2A),
                        iconEnabledColor: Colors.white.withValues(alpha: 0.76),
                        style: kVanMateFieldTextStyle,
                        items: VanCustomQuestionAnswerType.values
                            .map(
                              (type) =>
                                  DropdownMenuItem<VanCustomQuestionAnswerType>(
                                    value: type,
                                    child: Text(type.label),
                                  ),
                            )
                            .toList(growable: false),
                        decoration: vanMateFieldDecoration(
                          label: 'Answer type',
                          hintText: 'Choose answer type',
                          prefixIcon: const Icon(Icons.tune_rounded),
                          labelOpacity: 0.68,
                          hintOpacity: 0.48,
                        ),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _answerType = value;
                          });
                        },
                      ),
                      if (_answerType ==
                          VanCustomQuestionAnswerType.multipleChoice) ...[
                        const SizedBox(height: 12),
                        _EditorField(
                          controller: _choiceOptionsController,
                          label: 'Choices (comma separated)',
                          hint: 'Yes, No, Not sure',
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<VanCustomQuestionCategory?>(
                        initialValue: _category,
                        dropdownColor: const Color(0xFF131B2A),
                        iconEnabledColor: Colors.white.withValues(alpha: 0.76),
                        style: kVanMateFieldTextStyle,
                        items: <DropdownMenuItem<VanCustomQuestionCategory?>>[
                          const DropdownMenuItem<VanCustomQuestionCategory?>(
                            value: null,
                            child: Text('No category'),
                          ),
                          ...VanCustomQuestionCategory.values.map(
                            (category) =>
                                DropdownMenuItem<VanCustomQuestionCategory?>(
                                  value: category,
                                  child: Text(category.label),
                                ),
                          ),
                        ],
                        decoration: vanMateFieldDecoration(
                          label: 'Category',
                          hintText: 'Choose category',
                          prefixIcon: const Icon(Icons.category_outlined),
                          labelOpacity: 0.68,
                          hintOpacity: 0.48,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _category = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                        title: const Text(
                          'Active question',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          'Inactive questions stay saved for later.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    SizedBox(
                      height: 42,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveQuestion,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_isEditing ? 'Save' : 'Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VanQuestionTemplateEditorPage extends StatefulWidget {
  const VanQuestionTemplateEditorPage({
    super.key,
    this.template,
    required this.customQuestions,
    this.initialSelectedQuestionIds,
  });

  final VanQuestionTemplate? template;
  final List<VanCustomJobQuestion> customQuestions;
  final Set<String>? initialSelectedQuestionIds;

  @override
  State<VanQuestionTemplateEditorPage> createState() =>
      _VanQuestionTemplateEditorPageState();
}

class _VanQuestionTemplateEditorPageState
    extends State<VanQuestionTemplateEditorPage> {
  final VanQuestionTemplatesStorage _storage =
      VanQuestionTemplatesStorage.instance;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late bool _isActive;
  late Set<String> _selectedIds;
  bool _saving = false;

  bool get _isEditing => widget.template != null;
  List<VanCustomJobQuestion> get _activeCustomQuestions => widget
      .customQuestions
      .where((question) => !question.isArchived)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _nameController = TextEditingController(text: template?.name ?? '');
    _descriptionController = TextEditingController(
      text: template?.description ?? '',
    );
    _isActive = template?.isActive ?? true;
    _selectedIds = <String>{
      ...(template?.selectedQuestionIds ?? const <String>[]),
      ...(widget.initialSelectedQuestionIds ?? const <String>{}),
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id, bool value) {
    setState(() {
      if (value) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  Future<void> _saveTemplate() async {
    if (_saving) {
      return;
    }

    final name = _sanitizeQuestionInput(_nameController.text);
    if (name.isEmpty) {
      _showSnack('Please enter a template name.');
      return;
    }
    if (_selectedIds.isEmpty) {
      _showSnack('Please select at least one question.');
      return;
    }

    final now = DateTime.now();
    final existing = widget.template;
    final template = VanQuestionTemplate(
      id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
      name: name,
      description: _sanitizeQuestionInput(_descriptionController.text),
      selectedQuestionIds: List<String>.unmodifiable(_selectedIds.toList()),
      isActive: _isActive,
      isArchived: existing?.isArchived ?? false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() {
      _saving = true;
    });

    try {
      await _storage.upsert(template);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      _showSnack('Could not save template.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final title = _isEditing ? 'Edit Template' : 'Add Template';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title),
        leadingWidth: 96,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: VanBackBusinessHubButtons(
            onBack: () => Navigator.of(context).pop(false),
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
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Build reusable template sets for each service.',
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
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Template Details',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _EditorField(
                        controller: _nameController,
                        label: 'Template name',
                        hint: 'Man & Van Template',
                      ),
                      const SizedBox(height: 12),
                      _EditorField(
                        controller: _descriptionController,
                        label: 'Description (optional)',
                        hint: 'When to use this template',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                        title: const Text(
                          'Active template',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          'Inactive templates stay saved for later.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _GlassCard(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Select Questions',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          _StatusChip(
                            label: '${_selectedIds.length} selected',
                            color: const Color(0xFF4A7DFF),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final category in VanCustomQuestionCategory.values)
                        ..._buildTemplateCategoryQuestions(category),
                      if (_activeCustomQuestions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'My Questions',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (
                          var i = 0;
                          i < _activeCustomQuestions.length;
                          i++
                        ) ...[
                          _QuestionTickRow(
                            question: _activeCustomQuestions[i],
                            value: _selectedIds.contains(
                              _activeCustomQuestions[i].id,
                            ),
                            onChanged: (value) => _toggleSelection(
                              _activeCustomQuestions[i].id,
                              value,
                            ),
                          ),
                          if (i < _activeCustomQuestions.length - 1)
                            Divider(
                              color: Colors.white.withValues(alpha: 0.10),
                              height: 1,
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    SizedBox(
                      height: 42,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveTemplate,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_isEditing ? 'Save' : 'Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTemplateCategoryQuestions(
    VanCustomQuestionCategory category,
  ) {
    final items = VanPrefilledJobQuestions.byCategory(category);
    if (items.isEmpty) {
      return const <Widget>[];
    }

    return <Widget>[
      Text(
        category.label,
        style: const TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < items.length; i++) ...[
        _QuestionTickRow(
          question: items[i],
          value: _selectedIds.contains(items[i].id),
          onChanged: (value) => _toggleSelection(items[i].id, value),
        ),
        if (i < items.length - 1)
          Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),
      ],
      const SizedBox(height: 10),
    ];
  }
}

class _QuestionTickRow extends StatelessWidget {
  const _QuestionTickRow({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final VanCustomJobQuestion question;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: const Color(0xFF4A7DFF),
      onChanged: (checked) => onChanged(checked ?? false),
      title: Text(
        question.questionText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13.3,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: question.hasCategory
          ? Text(
              '${question.answerType.label} • ${question.category!.label}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: 11.7,
                fontWeight: FontWeight.w600,
              ),
            )
          : Text(
              question.answerType.label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: 11.7,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.20),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11.2,
        ),
      ),
    );
  }
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
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
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
        child: Container(
          width: double.infinity,
          padding: padding,
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
