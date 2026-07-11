import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/van_custom_job_question.dart';
import 'van_business_profile_scope_storage.dart';
import 'van_custom_job_questions_cloud_service.dart';
import 'van_firebase_auth_service.dart';
import 'van_firebase_debug_logging.dart';

class VanCustomJobQuestionsStorage extends ChangeNotifier {
  VanCustomJobQuestionsStorage._();

  static final VanCustomJobQuestionsStorage instance =
      VanCustomJobQuestionsStorage._();

  static const String _questionsKey = 'van_custom_job_questions_v1';

  SharedPreferences? _preferences;
  Future<void>? _loadFuture;
  bool _isLoaded = false;

  Future<void> ensureLoaded() {
    if (_isLoaded) {
      return Future<void>.value();
    }
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    _preferences = await SharedPreferences.getInstance();
    _isLoaded = true;
  }

  Future<List<VanCustomJobQuestion>> loadAll() async {
    await ensureLoaded();
    final storageKey = await VanBusinessProfileScopeStorage.instance
        .scopedLocalKey(_questionsKey);
    final raw = _preferences?.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <VanCustomJobQuestion>[];
    }

    final decoded = jsonDecode(raw);
    final items = <VanCustomJobQuestion>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          items.add(
            VanCustomJobQuestion.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    items.sort(_sortQuestions);
    return items;
  }

  Future<List<VanCustomJobQuestion>> loadReusableQuestions() async {
    final all = await loadAll();
    return all
        .where((question) => question.isActive && !question.isArchived)
        .toList(growable: false);
  }

  Future<List<String>> loadReusableQuestionTexts() async {
    final reusable = await loadReusableQuestions();
    return reusable
        .map((question) => question.questionText.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<VanCustomJobQuestion>?> loadFromCloud() async {
    if (!await VanBusinessProfileScopeStorage.instance
        .isDefaultBusinessActive()) {
      return loadAll();
    }
    logVanFirebaseHydration(
      stage: 'started',
      target: 'custom questions cloud load',
    );
    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.custom_questions_load',
    );
    if (ownerUid == null || ownerUid.trim().isEmpty) {
      logVanFirebaseSkip(
        reason: 'custom questions cloud load skipped',
        extra: 'uid=$ownerUid',
      );
      return null;
    }

    try {
      final questions = await VanCustomJobQuestionsCloudService.instance
          .loadQuestions(ownerUid: ownerUid);
      if (questions == null) {
        logVanFirebaseHydration(
          stage: 'completed',
          target: 'custom questions cloud load',
          extra: 'no_cloud_doc uid=$ownerUid',
        );
        return null;
      }

      final localQuestions = await loadAll();
      if (localQuestions.isNotEmpty &&
          !_shouldReplaceLocal(localQuestions, questions)) {
        logVanFirebaseSkip(
          reason: 'custom questions cloud load skipped newer local state',
          extra:
              'uid=$ownerUid local=${localQuestions.length} cloud=${questions.length}',
        );
        return localQuestions;
      }

      await saveAll(questions, syncCloud: false);
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'custom questions cloud load',
        extra: 'uid=$ownerUid count=${questions.length}',
      );
      return questions;
    } catch (error) {
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'custom questions cloud load',
        extra: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> saveAll(
    List<VanCustomJobQuestion> questions, {
    bool syncCloud = true,
  }) async {
    await ensureLoaded();
    final storageKey = await VanBusinessProfileScopeStorage.instance
        .scopedLocalKey(_questionsKey);
    final sorted = List<VanCustomJobQuestion>.from(questions)
      ..sort(_sortQuestions);
    await _preferences?.setString(
      storageKey,
      jsonEncode(
        sorted.map((question) => question.toJson()).toList(growable: false),
      ),
    );
    debugPrint('[CustomQuestions] saved count=${sorted.length}');
    notifyListeners();

    if (!syncCloud ||
        !await VanBusinessProfileScopeStorage.instance
            .isDefaultBusinessActive()) {
      return;
    }

    try {
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.custom_questions_save',
      );
      if (ownerUid == null || ownerUid.trim().isEmpty) {
        return;
      }

      await VanCustomJobQuestionsCloudService.instance.saveQuestions(
        ownerUid: ownerUid,
        questions: sorted,
      );
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'custom questions cloud save',
        extra: 'uid=$ownerUid count=${sorted.length}',
      );
    } catch (error) {
      debugPrint('[CustomQuestions] cloud save failed: $error');
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'custom questions cloud save',
        extra: error.toString(),
      );
    }
  }

  Future<void> upsert(VanCustomJobQuestion question) async {
    final all = await loadAll();
    final next = <VanCustomJobQuestion>[
      question,
      for (final item in all)
        if (item.id != question.id) item,
    ];
    await saveAll(next);
  }

  Future<void> setActive(String questionId, bool value) async {
    final all = await loadAll();
    final now = DateTime.now();
    final updated = all
        .map(
          (item) => item.id == questionId
              ? item.copyWith(isActive: value, updatedAt: now)
              : item,
        )
        .toList(growable: false);
    await saveAll(updated);
  }

  Future<void> setArchived(String questionId, bool value) async {
    final all = await loadAll();
    final now = DateTime.now();
    final updated = all
        .map(
          (item) => item.id == questionId
              ? item.copyWith(
                  isArchived: value,
                  isActive: value ? false : item.isActive,
                  updatedAt: now,
                )
              : item,
        )
        .toList(growable: false);
    await saveAll(updated);
  }

  Future<void> delete(String questionId) async {
    final all = await loadAll();
    final updated = all
        .where((question) => question.id != questionId)
        .toList(growable: false);
    await saveAll(updated);
  }

  Future<void> clear() async {
    await ensureLoaded();
    final storageKey = await VanBusinessProfileScopeStorage.instance
        .scopedLocalKey(_questionsKey);
    await _preferences?.remove(storageKey);
    notifyListeners();

    if (!await VanBusinessProfileScopeStorage.instance
        .isDefaultBusinessActive()) {
      return;
    }

    try {
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.custom_questions_clear',
      );
      if (ownerUid == null || ownerUid.trim().isEmpty) {
        return;
      }
      await VanCustomJobQuestionsCloudService.instance.clearQuestions(
        ownerUid: ownerUid,
      );
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'custom questions cloud clear',
        extra: 'uid=$ownerUid',
      );
    } catch (error) {
      debugPrint('[CustomQuestions] cloud clear failed: $error');
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'custom questions cloud clear',
        extra: error.toString(),
      );
    }
  }

  int _sortQuestions(VanCustomJobQuestion a, VanCustomJobQuestion b) {
    if (a.isArchived != b.isArchived) {
      return a.isArchived ? 1 : -1;
    }
    if (a.isActive != b.isActive) {
      return a.isActive ? -1 : 1;
    }
    return b.updatedAt.compareTo(a.updatedAt);
  }

  bool _shouldReplaceLocal(
    List<VanCustomJobQuestion> local,
    List<VanCustomJobQuestion> cloud,
  ) {
    if (local.isEmpty) {
      return true;
    }
    if (cloud.isEmpty) {
      return false;
    }

    final localLatest = local
        .map((item) => item.updatedAt)
        .reduce((value, element) => value.isAfter(element) ? value : element);
    final cloudLatest = cloud
        .map((item) => item.updatedAt)
        .reduce((value, element) => value.isAfter(element) ? value : element);
    return cloudLatest.isAfter(localLatest);
  }
}
