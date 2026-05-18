import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';

class VanMateExactPinNotificationPayload {
  const VanMateExactPinNotificationPayload({
    required this.type,
    required this.requestId,
    required this.dropId,
    required this.dropName,
  });

  final String type;
  final String requestId;
  final String dropId;
  final String dropName;

  bool get isPinResponseNotification =>
      type == 'exact_pin_received' || type == 'location_note_received';

  bool get isExactPinReceived => type == 'exact_pin_received';

  String get displayDropName {
    final trimmed = dropName.trim();
    return trimmed.isEmpty ? 'A customer/site' : trimmed;
  }

  String get snackbarBody => type == 'location_note_received'
      ? (dropName.trim().isNotEmpty
            ? 'Location note received for ${dropName.trim()}'
            : 'Location note received')
      : dropName.trim().isNotEmpty
      ? 'Exact pin received for ${dropName.trim()}'
      : 'Exact pin received for this drop';

  String get notificationTitle {
    if (type == 'exact_pin_received') {
      return 'Exact pin received';
    }
    if (type == 'location_note_received') {
      return 'Location note received';
    }
    return 'Van Mate';
  }

  String get notificationBody {
    if (type == 'location_note_received') {
      return dropName.trim().isNotEmpty
          ? '${dropName.trim()} sent location details.'
          : 'A customer/site sent location details.';
    }

    return dropName.trim().isNotEmpty
        ? '${dropName.trim()} shared a location pin.'
        : 'A customer/site shared a location pin.';
  }

  static VanMateExactPinNotificationPayload? fromMap(
    Map<String, dynamic> data,
  ) {
    final type = _readString(data['type']);
    final requestId = _readString(data['requestId']);
    final dropId = _readString(data['dropId']);
    final dropName = _readString(data['dropName']);

    if (type.isEmpty || requestId.isEmpty) {
      return null;
    }

    return VanMateExactPinNotificationPayload(
      type: type,
      requestId: requestId,
      dropId: dropId,
      dropName: dropName,
    );
  }

  static String _readString(dynamic value) {
    return value?.toString().trim() ?? '';
  }
}

class VanMatePushNotificationService {
  VanMatePushNotificationService._({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    AuthService? authService,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _authService = authService ?? AuthService.instance;

  static final VanMatePushNotificationService instance =
      VanMatePushNotificationService._();

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final AuthService _authService;

  GlobalKey<ScaffoldMessengerState>? _scaffoldMessengerKey;
  StreamSubscription<String>? _tokenRefreshSubscription;

  bool _isInitialized = false;
  bool _isProcessingUserSync = false;
  String? _currentUid;
  String? _currentToken;
  String? _permissionPromptedForUid;
  void Function(VanMateExactPinNotificationPayload payload)?
  _openNotificationHandler;
  VanMateExactPinNotificationPayload? _pendingOpenNotification;

  Future<void> initialize({
    required GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
  }) async {
    _scaffoldMessengerKey = scaffoldMessengerKey;

    if (_isInitialized) {
      return;
    }
    _isInitialized = true;

    FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(_syncForUser(user));
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedMessage(initialMessage);
    }

    unawaited(_syncForUser(_authService.currentUser));
  }

  void registerOpenHandler(
    void Function(VanMateExactPinNotificationPayload payload) handler,
  ) {
    _openNotificationHandler = handler;
    _flushPendingOpenNotification();
  }

  void clearOpenHandler() {
    if (_openNotificationHandler != null) {
      _openNotificationHandler = null;
    }
  }

  Future<void> _syncForUser(User? user) async {
    if (_isProcessingUserSync) {
      return;
    }

    if (!_supportsNativePushNotifications) {
      return;
    }

    _isProcessingUserSync = true;
    try {
      final uid = user?.uid.trim() ?? '';
      if (uid.isEmpty) {
        await _clearTokenEnrollment();
        return;
      }

      if (_currentUid != uid) {
        await _clearTokenEnrollment();
        _currentUid = uid;
      }

      if (_shouldRequestPermissionForUid(uid)) {
        try {
          await _messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );
        } catch (error, stackTrace) {
          debugPrint('FCM permission request failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        } finally {
          _permissionPromptedForUid = uid;
        }
      }

      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        return;
      }

      await _storeCurrentToken(uid: uid, token: token.trim());
      _listenForTokenRefresh(uid: uid);
    } catch (error, stackTrace) {
      debugPrint('FCM setup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isProcessingUserSync = false;
    }
  }

  bool _shouldRequestPermissionForUid(String uid) {
    return _supportsNativePushNotifications && _permissionPromptedForUid != uid;
  }

  bool get _supportsNativePushNotifications {
    if (kIsWeb) {
      return false;
    }

    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final payload = VanMateExactPinNotificationPayload.fromMap(message.data);
    if (payload == null || !payload.isPinResponseNotification) {
      return;
    }

    final messenger = _scaffoldMessengerKey?.currentState;
    if (messenger == null || !messenger.mounted) {
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(payload.snackbarBody),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => _queueOpenNotification(payload),
          ),
        ),
      );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final payload = VanMateExactPinNotificationPayload.fromMap(message.data);
    if (payload == null || !payload.isPinResponseNotification) {
      return;
    }

    _queueOpenNotification(payload);
  }

  void _queueOpenNotification(VanMateExactPinNotificationPayload payload) {
    _pendingOpenNotification = payload;
    _flushPendingOpenNotification();
  }

  void _flushPendingOpenNotification() {
    final payload = _pendingOpenNotification;
    final handler = _openNotificationHandler;
    if (payload == null || handler == null) {
      return;
    }

    _pendingOpenNotification = null;
    scheduleMicrotask(() => handler(payload));
  }

  Future<void> _storeCurrentToken({
    required String uid,
    required String token,
  }) async {
    final docId = _tokenDocId(token);
    if (_currentToken != null && _currentToken != token && _currentUid == uid) {
      await _deleteTokenDoc(uid: uid, tokenDocId: _tokenDocId(_currentToken!));
    }

    _currentToken = token;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .doc(docId)
        .set(<String, dynamic>{
          'token': token,
          'platform': _platformLabel,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _deleteTokenDoc({
    required String uid,
    required String tokenDocId,
  }) async {
    if (tokenDocId.trim().isEmpty) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(tokenDocId)
          .delete();
    } catch (error, stackTrace) {
      debugPrint('FCM token cleanup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _listenForTokenRefresh({required String uid}) {
    final subscription = _tokenRefreshSubscription;
    if (subscription != null) {
      return;
    }

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) {
      final trimmedToken = token.trim();
      if (trimmedToken.isEmpty) {
        return;
      }

      unawaited(_storeCurrentToken(uid: uid, token: trimmedToken));
    });
  }

  Future<void> _clearTokenEnrollment() async {
    final uid = _currentUid;
    final token = _currentToken;
    _currentUid = null;
    _currentToken = null;
    _permissionPromptedForUid = null;

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;

    if (uid == null || uid.trim().isEmpty || token == null || token.isEmpty) {
      return;
    }

    await _deleteTokenDoc(uid: uid, tokenDocId: _tokenDocId(token));
  }

  String _tokenDocId(String token) {
    final encoded = base64Url.encode(utf8.encode(token));
    return encoded.replaceAll('=', '');
  }

  String get _platformLabel {
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.android) return 'android';
    if (platform == TargetPlatform.iOS) return 'ios';
    return platform.name;
  }
}
