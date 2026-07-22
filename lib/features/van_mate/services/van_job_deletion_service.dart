import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'van_business_profile_scope_storage.dart';

enum VanJobDeletionSelection { explicit, testJobs, allOperational }

extension on VanJobDeletionSelection {
  String get wireValue => switch (this) {
    VanJobDeletionSelection.explicit => 'explicit',
    VanJobDeletionSelection.testJobs => 'test_jobs',
    VanJobDeletionSelection.allOperational => 'all_operational',
  };
}

class VanJobDeletionException implements Exception {
  const VanJobDeletionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VanJobDeletionTarget {
  const VanJobDeletionTarget({required this.jobId, this.requestId = ''});

  final String jobId;
  final String requestId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'jobId': jobId.trim(),
    if (requestId.trim().isNotEmpty) 'requestId': requestId.trim(),
  };
}

class VanJobDeletionSummary {
  const VanJobDeletionSummary({
    required this.jobs,
    required this.requests,
    required this.quoteVersions,
    required this.tokens,
    required this.photos,
    required this.invoicesPreserved,
    required this.ambiguousPreserved,
  });

  factory VanJobDeletionSummary.fromJson(Map<String, dynamic> json) {
    int count(String key) => (json[key] as num?)?.toInt() ?? 0;
    return VanJobDeletionSummary(
      jobs: count('jobs'),
      requests: count('requests'),
      quoteVersions: count('quoteVersions'),
      tokens: count('tokens'),
      photos: count('photos'),
      invoicesPreserved: count('invoicesPreserved'),
      ambiguousPreserved: count('ambiguousPreserved'),
    );
  }

  final int jobs;
  final int requests;
  final int quoteVersions;
  final int tokens;
  final int photos;
  final int invoicesPreserved;
  final int ambiguousPreserved;
}

class VanJobDeletionPreviewTarget {
  const VanJobDeletionPreviewTarget({
    required this.jobId,
    required this.requestId,
    required this.status,
  });

  factory VanJobDeletionPreviewTarget.fromJson(Map<String, dynamic> json) =>
      VanJobDeletionPreviewTarget(
        jobId: json['jobId']?.toString().trim() ?? '',
        requestId: json['requestId']?.toString().trim() ?? '',
        status: json['status']?.toString().trim() ?? 'unknown',
      );

  final String jobId;
  final String requestId;
  final String status;
}

class VanJobDeletionPreview {
  const VanJobDeletionPreview({
    required this.businessProfileId,
    required this.selection,
    required this.previewToken,
    required this.confirmationPhrase,
    required this.expiresAt,
    required this.targets,
    required this.summary,
  });

  final String businessProfileId;
  final VanJobDeletionSelection selection;
  final String previewToken;
  final String confirmationPhrase;
  final DateTime? expiresAt;
  final List<VanJobDeletionPreviewTarget> targets;
  final VanJobDeletionSummary summary;
}

class VanJobDeletionTargetResult {
  const VanJobDeletionTargetResult({
    required this.jobId,
    required this.requestId,
    required this.status,
    this.error = '',
  });

  factory VanJobDeletionTargetResult.fromJson(Map<String, dynamic> json) =>
      VanJobDeletionTargetResult(
        jobId: json['jobId']?.toString().trim() ?? '',
        requestId: json['requestId']?.toString().trim() ?? '',
        status: json['status']?.toString().trim() ?? 'failed',
        error: json['error']?.toString().trim() ?? '',
      );

  final String jobId;
  final String requestId;
  final String status;
  final String error;

  bool get completed => status == 'deleted' || status == 'already_deleted';
}

class VanJobDeletionExecution {
  const VanJobDeletionExecution({
    required this.operationId,
    required this.results,
  });

  final String operationId;
  final List<VanJobDeletionTargetResult> results;

  List<VanJobDeletionTargetResult> get completed =>
      results.where((result) => result.completed).toList(growable: false);
  List<VanJobDeletionTargetResult> get failed =>
      results.where((result) => !result.completed).toList(growable: false);
}

typedef VanJobDeletionCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

class VanJobDeletionService {
  VanJobDeletionService({
    VanJobDeletionCallable? callable,
    Future<VanBusinessProfileSummary> Function()? activeProfile,
    DateTime Function()? now,
  }) : _callable = callable ?? _defaultCallable,
       _activeProfile =
           activeProfile ??
           VanBusinessProfileScopeStorage.instance.activeProfile,
       _now = now ?? DateTime.now;

  static final VanJobDeletionService instance = VanJobDeletionService();

  final VanJobDeletionCallable _callable;
  final Future<VanBusinessProfileSummary> Function() _activeProfile;
  final DateTime Function() _now;

  static Future<Map<String, dynamic>> _defaultCallable(
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('deleteBusinessMateJobs')
          .call<Map<String, dynamic>>(data)
          .timeout(const Duration(seconds: 45));
      return Map<String, dynamic>.from(result.data);
    } on FirebaseFunctionsException catch (error) {
      throw VanJobDeletionException(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Job deletion could not be completed.',
      );
    } on TimeoutException {
      throw const VanJobDeletionException(
        'Job deletion is taking longer than expected. Please retry safely.',
      );
    } catch (error) {
      debugPrint('[JobDeletion] callable failed: $error');
      if (error is VanJobDeletionException) rethrow;
      throw const VanJobDeletionException(
        'Job deletion could not be completed. Please try again.',
      );
    }
  }

  Future<VanJobDeletionPreview> preview({
    required VanJobDeletionSelection selection,
    List<VanJobDeletionTarget> targets = const <VanJobDeletionTarget>[],
  }) async {
    final profile = await _activeProfile();
    final data = await _callable(<String, dynamic>{
      'mode': 'preview',
      'selection': selection.wireValue,
      'businessProfileId': profile.id,
      'targets': targets
          .map((target) => target.toJson())
          .toList(growable: false),
    });
    final rawTargets = data['targets'] is List
        ? List<dynamic>.from(data['targets'] as List)
        : const <dynamic>[];
    return VanJobDeletionPreview(
      businessProfileId: profile.id,
      selection: selection,
      previewToken: data['previewToken']?.toString().trim() ?? '',
      confirmationPhrase: data['confirmationPhrase']?.toString() ?? '',
      expiresAt: DateTime.tryParse(data['expiresAt']?.toString() ?? ''),
      targets: rawTargets
          .whereType<Map>()
          .map(
            (target) => VanJobDeletionPreviewTarget.fromJson(
              Map<String, dynamic>.from(target),
            ),
          )
          .toList(growable: false),
      summary: VanJobDeletionSummary.fromJson(
        data['summary'] is Map
            ? Map<String, dynamic>.from(data['summary'] as Map)
            : const <String, dynamic>{},
      ),
    );
  }

  Future<VanJobDeletionExecution> execute(
    VanJobDeletionPreview preview, {
    required String confirmationPhrase,
  }) async {
    final operationId =
        'job_delete_${_now().microsecondsSinceEpoch}_${preview.previewToken.hashCode.abs()}';
    final data = await _callable(<String, dynamic>{
      'mode': 'execute',
      'selection': preview.selection.wireValue,
      'businessProfileId': preview.businessProfileId,
      'previewToken': preview.previewToken,
      'confirmationPhrase': confirmationPhrase,
      'idempotencyKey': operationId,
    });
    final rawResults = data['results'] is List
        ? List<dynamic>.from(data['results'] as List)
        : const <dynamic>[];
    return VanJobDeletionExecution(
      operationId: data['operationId']?.toString().trim() ?? operationId,
      results: rawResults
          .whereType<Map>()
          .map(
            (result) => VanJobDeletionTargetResult.fromJson(
              Map<String, dynamic>.from(result),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<VanJobDeletionExecution> deleteOne({
    required String jobId,
    String requestId = '',
  }) async {
    final preview = await this.preview(
      selection: VanJobDeletionSelection.explicit,
      targets: <VanJobDeletionTarget>[
        VanJobDeletionTarget(jobId: jobId, requestId: requestId),
      ],
    );
    if (preview.targets.length != 1 ||
        preview.targets.single.jobId != jobId.trim()) {
      throw const VanJobDeletionException(
        'Firebase could not verify this exact job for deletion.',
      );
    }
    return execute(preview, confirmationPhrase: preview.confirmationPhrase);
  }
}
