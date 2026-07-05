import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import 'van_customer_request_actions.dart';
import '../models/van_pin_request.dart';
import '../models/van_place.dart';
import '../models/van_route_stop.dart';
import '../services/auth_service.dart';
import '../services/van_pin_request_service.dart';
import '../services/van_premium_service.dart';
import '../widgets/van_premium_gate_sheet.dart';

const String _kLivePinRequestFeatureName = 'Live Pin Request';
const String _kLivePinRequestHeadline = 'Live Pin Request is Premium';
const String _kLivePinRequestMessage =
    'Ask a customer or site contact to share the exact entrance, bay, gate, collection point, or drop-off pin, then save it as the drop pin.';

enum VanPinRequestMessageKind { savedDrop, emergencyNumberOnly }

String buildVanPinRequestMessage({
  required String requestLink,
  String? dropName,
  VanPinRequestMessageKind kind = VanPinRequestMessageKind.savedDrop,
}) {
  final resolvedLink = requestLink.trim();
  final resolvedName = dropName?.trim() ?? '';
  final message = StringBuffer();
  if (kind == VanPinRequestMessageKind.emergencyNumberOnly) {
    message.write(
      'Hi, I\'m trying to find the correct pickup/drop-off point.\n\n',
    );
    message.write(
      'Please tap this link and share the exact entrance, bay, gate, collection point, or drop-off pin:\n\n',
    );
    message.write(resolvedLink);
    message.write(
      '\n\nIt only sends one location pin, not live tracking.\n\nIf you\'re not there, please forward the link to someone on site or reply with access instructions.\n\nThanks.',
    );
    return normalizeOutgoingRequestMessage(message.toString());
  }

  message.write('Hi, I\'m delivering to ');
  message.write(resolvedName.isEmpty ? 'you' : resolvedName);
  message.write(' today.\n\n');
  message.write(
    'Please tap this link and share the exact delivery entrance/drop-off pin:\n\n',
  );
  message.write(resolvedLink);
  message.write(
    '\n\nBefore sharing, you will be asked whether you are actually at the pickup/drop-off point now.\n\nOnly share your location if you are at the correct delivery entrance/drop-off point.\n\nIf you are not there, please forward this link to someone on site, or reply with access instructions.\n\nIt only sends one location pin, not live tracking.\n\nThanks.',
  );

  return normalizeOutgoingRequestMessage(message.toString());
}

String buildVanEmergencyPinRequestMessage({required String requestLink}) {
  return buildVanPinRequestMessage(
    requestLink: requestLink,
    kind: VanPinRequestMessageKind.emergencyNumberOnly,
  );
}

String buildVanLivePinRequestLink(String requestId) {
  return VanPinRequestService.instance.buildRequestUrl(requestId);
}

String buildVanLivePinRequestLinkFromDoc(VanPinRequest request) {
  final link = request.requestUrl.trim();
  return link.isNotEmpty ? link : buildVanLivePinRequestLink(request.id);
}

Future<VanPinRequest?> requestVanLivePinForPlace(
  BuildContext context,
  VanPlace place, {
  bool copyLinkInstead = false,
  String? recipientPhoneNumber,
  String? successMessage,
}) async {
  return await _requestVanLivePin(
    context,
    dropName: place.name,
    address: place.address,
    postcodeArea: place.postcodeArea,
    createRequest: () =>
        VanPinRequestService.instance.createRequestForPlace(place),
    copyLinkInstead: copyLinkInstead,
    recipientPhoneNumber: recipientPhoneNumber,
    successMessage: successMessage,
  );
}

Future<void> openVanGoogleMapsAtCoordinates(
  BuildContext context, {
  required double latitude,
  required double longitude,
}) async {
  final query = '$latitude,$longitude';
  final uri = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': query,
  });

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!context.mounted || launched) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not open Google Maps just now.')),
  );
}

Future<VanPinRequest?> requestVanEmergencyPinForPhoneNumber(
  BuildContext context, {
  required String phoneNumber,
  String? driverNote,
}) async {
  debugPrint('Emergency pin request tapped');

  final premiumService = VanMatePremiumService.instance;
  await premiumService.ensureLoaded();

  if (!context.mounted) {
    return null;
  }
  final premiumAllowed = premiumService.isPremium;
  debugPrint('Premium active: $premiumAllowed');

  if (!premiumAllowed) {
    await requireVanMatePremium(
      context,
      featureName: _kLivePinRequestFeatureName,
      headline: _kLivePinRequestHeadline,
      message:
          'Send a one-time exact pin request before creating a drop when paperwork is incomplete.',
      ctaLabel: 'Open Premium screen',
    );
    return null;
  }

  if (!context.mounted) {
    return null;
  }

  final messenger = ScaffoldMessenger.of(context);

  String? currentUid;
  try {
    currentUid = await AuthService.instance.ensureCurrentUid(
      source: 'van_mate.pin_request',
    );
  } catch (e, st) {
    debugPrint('Create emergency request failed: $e');
    debugPrintStack(stackTrace: st);
    _showMessage(messenger, _buildCreateRequestFailureMessage(e));
    return null;
  }

  if (currentUid == null || currentUid.isEmpty) {
    _showMessage(messenger, 'Please sign in to request an exact pin.');
    return null;
  }

  final normalizedPhone = phoneNumber.trim();
  if (normalizedPhone.isEmpty) {
    _showMessage(messenger, 'Please enter a phone number.');
    return null;
  }

  VanPinRequest? request;
  try {
    request = await VanPinRequestService.instance.createEmergencyRequest(
      phoneNumber: normalizedPhone,
      driverNote: driverNote,
    );
  } catch (e, st) {
    debugPrint('Create emergency request failed: $e');
    debugPrintStack(stackTrace: st);
    _showMessage(messenger, _buildCreateRequestFailureMessage(e));
    return null;
  }

  if (request == null) {
    _showMessage(
      messenger,
      _buildCreateRequestFailureMessage(
        StateError('createEmergencyRequest returned null'),
      ),
    );
    return null;
  }

  final link = buildVanLivePinRequestLinkFromDoc(request);
  final message = buildVanEmergencyPinRequestMessage(requestLink: link);

  try {
    final smsUri = Uri(
      scheme: 'sms',
      path: normalizedPhone,
      queryParameters: <String, String>{'body': message},
    );
    final launched = await launchUrl(
      smsUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      await Clipboard.setData(ClipboardData(text: message));
      _showMessage(
        messenger,
        'Emergency request copied. Paste it into a message.',
      );
    } else {
      _showMessage(messenger, 'Emergency request created.');
    }
  } catch (error) {
    debugPrint('Emergency request launch failed: $error');
    await Clipboard.setData(ClipboardData(text: message));
    _showMessage(
      messenger,
      'Emergency request copied. Paste it into a message.',
    );
  }

  return request;
}

Future<VanPinRequest?> requestVanLivePinForStop(
  BuildContext context,
  VanRouteStop stop, {
  bool copyLinkInstead = false,
  String? recipientPhoneNumber,
  String? successMessage,
}) async {
  return await _requestVanLivePin(
    context,
    dropName: stop.name,
    address: stop.address,
    postcodeArea: stop.postcodeArea,
    createRequest: () =>
        VanPinRequestService.instance.createRequestForStop(stop),
    copyLinkInstead: copyLinkInstead,
    recipientPhoneNumber: recipientPhoneNumber,
    successMessage: successMessage,
  );
}

Future<VanPinRequest?> copyVanLivePinRequestForPlace(
  BuildContext context,
  VanPlace place,
) async {
  return await requestVanLivePinForPlace(context, place, copyLinkInstead: true);
}

Future<VanPinRequest?> copyVanLivePinRequestForStop(
  BuildContext context,
  VanRouteStop stop,
) async {
  return await requestVanLivePinForStop(context, stop, copyLinkInstead: true);
}

Future<VanPinRequest?> _requestVanLivePin(
  BuildContext context, {
  required String dropName,
  required String address,
  required String postcodeArea,
  required Future<VanPinRequest?> Function() createRequest,
  bool copyLinkInstead = false,
  String? recipientPhoneNumber,
  String? successMessage,
}) async {
  debugPrint('Request exact pin tapped');

  final premiumService = VanMatePremiumService.instance;
  await premiumService.ensureLoaded();

  if (!context.mounted) {
    return null;
  }
  final premiumAllowed = premiumService.isPremium;
  debugPrint('Premium active: $premiumAllowed');

  if (!premiumAllowed) {
    await requireVanMatePremium(
      context,
      featureName: _kLivePinRequestFeatureName,
      headline: _kLivePinRequestHeadline,
      message: _kLivePinRequestMessage,
      ctaLabel: 'Open Premium screen',
    );
    return null;
  }

  if (!context.mounted) {
    return null;
  }

  final messenger = ScaffoldMessenger.of(context);

  String? currentUid;
  try {
    currentUid = await AuthService.instance.ensureCurrentUid(
      source: 'van_mate.pin_request',
    );
  } catch (e, st) {
    debugPrint('Create request link failed: $e');
    debugPrintStack(stackTrace: st);
    _showMessage(messenger, _buildCreateRequestFailureMessage(e));
    return null;
  }

  if (currentUid == null || currentUid.isEmpty) {
    _showMessage(messenger, 'Please sign in to request an exact pin.');
    return null;
  }

  debugPrint('Creating pin request...');
  debugPrint('Creating fresh exact pin request');

  VanPinRequest? request;
  try {
    request = await createRequest();
  } catch (e, st) {
    debugPrint('Create request link failed: $e');
    debugPrintStack(stackTrace: st);
    _showMessage(messenger, _buildCreateRequestFailureMessage(e));
    return null;
  }

  if (request == null) {
    debugPrint('Create request link failed: createRequest returned null');
    _showMessage(
      messenger,
      _buildCreateRequestFailureMessage(
        StateError('createRequest returned null'),
      ),
    );
    return null;
  }

  final link = buildVanLivePinRequestLinkFromDoc(request);
  debugPrint('Request URL: $link');

  if (!VanPinRequestService.instance.isHostingUrlConfigured) {
    _showMessage(
      messenger,
      'Request created, but hosting URL is not configured.',
    );
  }

  final message = buildVanPinRequestMessage(
    requestLink: link,
    dropName: dropName,
  );
  final fallbackClipboardText = copyLinkInstead ? link : message;

  if (successMessage != null && successMessage.trim().isNotEmpty) {
    _showMessage(messenger, successMessage.trim());
  }

  if (copyLinkInstead) {
    await Clipboard.setData(ClipboardData(text: link));
    _showMessage(messenger, 'Link copied.');
    return request;
  }

  final normalizedPhone = recipientPhoneNumber?.trim() ?? '';
  final hasRecipientPhone = normalizedPhone.isNotEmpty;
  if (hasRecipientPhone) {
    debugPrint('Opening SMS app...');
  } else {
    debugPrint('Opening share sheet...');
  }

  try {
    if (hasRecipientPhone) {
      final smsUri = Uri(
        scheme: 'sms',
        path: normalizedPhone,
        queryParameters: <String, String>{'body': message},
      );
      final launched = await launchUrl(
        smsUri,
        mode: LaunchMode.externalApplication,
      );
      debugPrint('Share sheet completed/failed: sms launched=$launched');

      if (!launched) {
        await Clipboard.setData(ClipboardData(text: fallbackClipboardText));
        _showMessage(messenger, 'Request copied. Paste it into a message.');
      }
    } else {
      final shareResult = await SharePlus.instance.share(
        ShareParams(text: message, subject: 'Request exact pin'),
      );
      debugPrint('Share sheet completed/failed: ${shareResult.status}');

      if (shareResult.status == ShareResultStatus.unavailable) {
        await Clipboard.setData(ClipboardData(text: fallbackClipboardText));
        _showMessage(messenger, 'Request copied. Paste it into a message.');
      }
    }
  } catch (error) {
    debugPrint('Share sheet completed/failed: $error');
    await Clipboard.setData(ClipboardData(text: fallbackClipboardText));
    _showMessage(messenger, 'Request copied. Paste it into a message.');
  }

  return request;
}

String _buildCreateRequestFailureMessage(Object error) {
  final shortError = _shortErrorText(error);
  if (kDebugMode) {
    return "Couldn't create request link: $shortError";
  }

  return "Couldn't create request link.";
}

String _shortErrorText(Object error) {
  final text = error.toString().trim();
  if (text.isEmpty) {
    return 'unknown error';
  }

  final firstLine = text.split('\n').first.trim();
  if (firstLine.isEmpty) {
    return 'unknown error';
  }

  if (firstLine.length <= 140) {
    return firstLine;
  }

  return '${firstLine.substring(0, 137)}...';
}

void _showMessage(ScaffoldMessengerState messenger, String message) {
  if (!messenger.mounted) {
    return;
  }

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
