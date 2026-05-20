import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

String _authTypeLabel(User? user) {
  if (user == null) {
    return 'none';
  }
  return user.isAnonymous ? 'anonymous' : 'authenticated';
}

String _firebaseErrorText(Object error) {
  if (error is FirebaseException) {
    final code = error.code.trim();
    final message = error.message?.trim() ?? '';
    return code.isEmpty
        ? message
        : '$code${message.isNotEmpty ? ': $message' : ''}';
  }
  return error.toString();
}

void logVanFirebaseStartup({
  required String stage,
  FirebaseAuth? auth,
  FirebaseFirestore? firestore,
  String? extra,
}) {
  final currentUser = auth?.currentUser;
  final projectId = firestore?.app.options.projectId ?? '';
  final appId = firestore?.app.options.appId ?? '';
  final buffer = StringBuffer('[VanFirebase][Startup] $stage');
  if (projectId.isNotEmpty) {
    buffer.write(' projectId=$projectId');
  }
  if (appId.isNotEmpty) {
    buffer.write(' appId=$appId');
  }
  if (currentUser != null) {
    buffer.write(
      ' uid=${currentUser.uid} anonymous=${currentUser.isAnonymous}',
    );
  } else {
    buffer.write(' uid=null anonymous=false');
  }
  if (extra != null && extra.trim().isNotEmpty) {
    buffer.write(' $extra');
  }
  debugPrint(buffer.toString());
}

void logVanFirebaseAuthState({
  required String stage,
  required User? user,
  String? extra,
}) {
  final buffer = StringBuffer('[VanFirebase][Auth] $stage');
  buffer.write(' uid=${user?.uid ?? 'null'}');
  buffer.write(' email=${user?.email ?? 'null'}');
  buffer.write(' anonymous=${user?.isAnonymous ?? false}');
  buffer.write(' authType=${_authTypeLabel(user)}');
  if (extra != null && extra.trim().isNotEmpty) {
    buffer.write(' $extra');
  }
  debugPrint(buffer.toString());
}

void logVanFirebaseHydration({
  required String stage,
  required String target,
  String? extra,
}) {
  final buffer = StringBuffer('[VanFirebase][Hydration] $stage target=$target');
  if (extra != null && extra.trim().isNotEmpty) {
    buffer.write(' $extra');
  }
  debugPrint(buffer.toString());
}

void logVanFirebaseWriteStart({
  required String collectionPath,
  required String docId,
  required String uid,
  String? source,
}) {
  final buffer = StringBuffer(
    '[VanFirebase][Write] start path=$collectionPath/$docId uid=$uid',
  );
  if (source != null && source.trim().isNotEmpty) {
    buffer.write(' source=${source.trim()}');
  }
  debugPrint(buffer.toString());
}

void logVanFirebaseWriteSuccess({
  required String collectionPath,
  required String docId,
  required String uid,
  String? source,
}) {
  final buffer = StringBuffer(
    '[VanFirebase][Write] success path=$collectionPath/$docId uid=$uid',
  );
  if (source != null && source.trim().isNotEmpty) {
    buffer.write(' source=${source.trim()}');
  }
  debugPrint(buffer.toString());
}

void logVanFirebaseWriteFailure({
  required String collectionPath,
  required String docId,
  required String uid,
  required Object error,
  String? source,
}) {
  final buffer = StringBuffer(
    '[VanFirebase][Write] failure path=$collectionPath/$docId uid=$uid',
  );
  if (source != null && source.trim().isNotEmpty) {
    buffer.write(' source=${source.trim()}');
  }
  buffer.write(' error=${_firebaseErrorText(error)}');
  debugPrint(buffer.toString());
}

void logVanFirebaseSkip({required String reason, String? extra}) {
  final buffer = StringBuffer('[VanFirebase][Skip] $reason');
  if (extra != null && extra.trim().isNotEmpty) {
    buffer.write(' $extra');
  }
  debugPrint(buffer.toString());
}
