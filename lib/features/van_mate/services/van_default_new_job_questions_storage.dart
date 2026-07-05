import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/van_default_new_job_question_set.dart';
import 'van_default_new_job_questions_cloud_service.dart';
import 'van_firebase_auth_service.dart';
import 'van_firebase_debug_logging.dart';

class VanDefaultNewJobQuestionsStorage extends ChangeNotifier {
  VanDefaultNewJobQuestionsStorage._();

  static final VanDefaultNewJobQuestionsStorage instance =
      VanDefaultNewJobQuestionsStorage._();

  static const String _storageKey = 'van_default_new_job_questions_v1';

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

  Future<VanDefaultNewJobQuestionSet?> load() async {
    await ensureLoaded();
    final raw = _preferences?.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }

    return VanDefaultNewJobQuestionSet.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  Future<VanDefaultNewJobQuestionSet> loadEffective() async {
    final set = await load();
    if (set == null || !set.hasQuestions) {
      return VanDefaultNewJobQuestionSet.starter();
    }
    return set;
  }

  Future<List<String>> loadQuestions() async {
    return (await loadEffective()).questions;
  }

  Future<List<String>> loadSavedQuestions() async {
    final set = await load();
    if (set == null) {
      return const <String>[];
    }
    return set.questions;
  }

  Future<VanDefaultNewJobQuestionSet?> loadFromCloud() async {
    logVanFirebaseHydration(
      stage: 'started',
      target: 'default new job questions cloud load',
    );
    final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
      source: 'van_mate.default_new_job_questions_load',
    );
    if (ownerUid == null || ownerUid.trim().isEmpty) {
      logVanFirebaseSkip(
        reason: 'default new job questions cloud load skipped',
        extra: 'uid=$ownerUid',
      );
      return null;
    }

    try {
      final set = await VanDefaultNewJobQuestionsCloudService.instance
          .loadQuestionSet(ownerUid: ownerUid);
      if (set == null) {
        logVanFirebaseHydration(
          stage: 'completed',
          target: 'default new job questions cloud load',
          extra: 'no_cloud_doc uid=$ownerUid',
        );
        return null;
      }

      final localSet = await load();
      if (localSet != null && !_shouldReplaceLocal(localSet, set)) {
        logVanFirebaseSkip(
          reason:
              'default new job questions cloud load skipped newer local state',
          extra:
              'uid=$ownerUid local=${localSet.questions.length} cloud=${set.questions.length}',
        );
        return localSet;
      }

      await save(set, syncCloud: false);
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'default new job questions cloud load',
        extra: 'uid=$ownerUid count=${set.questions.length}',
      );
      return set;
    } catch (error) {
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'default new job questions cloud load',
        extra: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> save(
    VanDefaultNewJobQuestionSet set, {
    bool syncCloud = true,
  }) async {
    await ensureLoaded();
    final normalized = set.copyWith(
      questions: List<String>.unmodifiable(
        set.questions
            .map((question) => question.trim())
            .where((question) => question.isNotEmpty)
            .toList(growable: false),
      ),
      updatedAt: DateTime.now(),
    );
    await _preferences?.setString(_storageKey, jsonEncode(normalized.toJson()));
    notifyListeners();

    if (!syncCloud) {
      return;
    }

    try {
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.default_new_job_questions_save',
      );
      if (ownerUid == null || ownerUid.trim().isEmpty) {
        return;
      }

      await VanDefaultNewJobQuestionsCloudService.instance.saveQuestionSet(
        ownerUid: ownerUid,
        set: normalized,
      );
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'default new job questions cloud save',
        extra: 'uid=$ownerUid count=${normalized.questions.length}',
      );
    } catch (error) {
      debugPrint('[DefaultNewJobQuestions] cloud save failed: $error');
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'default new job questions cloud save',
        extra: error.toString(),
      );
    }
  }

  Future<void> clear() async {
    await ensureLoaded();
    await _preferences?.remove(_storageKey);
    notifyListeners();

    try {
      final ownerUid = await VanFirebaseAuthService.instance.ensureCurrentUid(
        source: 'van_mate.default_new_job_questions_clear',
      );
      if (ownerUid == null || ownerUid.trim().isEmpty) {
        return;
      }

      await VanDefaultNewJobQuestionsCloudService.instance.clearQuestionSet(
        ownerUid: ownerUid,
      );
      logVanFirebaseHydration(
        stage: 'completed',
        target: 'default new job questions cloud clear',
        extra: 'uid=$ownerUid',
      );
    } catch (error) {
      debugPrint('[DefaultNewJobQuestions] cloud clear failed: $error');
      logVanFirebaseHydration(
        stage: 'failed',
        target: 'default new job questions cloud clear',
        extra: error.toString(),
      );
    }
  }

  bool _shouldReplaceLocal(
    VanDefaultNewJobQuestionSet local,
    VanDefaultNewJobQuestionSet cloud,
  ) {
    return cloud.updatedAt.isAfter(local.updatedAt);
  }
}
