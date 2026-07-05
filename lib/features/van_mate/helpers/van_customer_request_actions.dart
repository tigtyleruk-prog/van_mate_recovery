import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

String buildRequestShareMessage({
  required String link,
  String? customerName,
  String? jobTitle,
  String? businessName,
  String? address,
  bool exactPinRequested = false,
  bool exactPinRequestedAfterQuoteAccepted = false,
  bool includeJobLines = true,
}) {
  final cleanedLink = link.trim();
  final cleanedCustomerName = _cleanShareContext(customerName ?? '');
  final cleanedJobTitle = _cleanShareContext(jobTitle ?? '');
  final cleanedBusinessName = _cleanShareContext(businessName ?? '');

  final lines = <String>[
    cleanedCustomerName.isNotEmpty ? 'Hi $cleanedCustomerName,' : 'Hi,',
    '',
    'Please fill in this quick job request so I can prepare your quote.',
  ];

  if (exactPinRequestedAfterQuoteAccepted) {
    lines.add('');
    lines.add(
      'If you accept the quote later, I\'ll then ask for the exact pickup/drop-off pin.',
    );
  }

  if (includeJobLines) {
    if (cleanedJobTitle.isNotEmpty) {
      lines.add('');
      lines.add('Job: $cleanedJobTitle');
    }
  }

  lines.addAll(<String>[
    '',
    cleanedLink,
    '',
    cleanedBusinessName.isNotEmpty ? 'Thanks,' : 'Thanks',
  ]);
  if (cleanedBusinessName.isNotEmpty) {
    lines.add(cleanedBusinessName);
  }

  return normalizeOutgoingRequestMessage(lines.join('\n'));
}

String normalizeOutgoingRequestMessage(String message) {
  final normalized = message.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) {
    return '';
  }

  final lines = normalized.split('\n');
  final cleanedLines = <String>[];
  final seenUrls = <String>{};
  final urlPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);

  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      if (cleanedLines.isEmpty || cleanedLines.last.isEmpty) {
        continue;
      }
      cleanedLines.add('');
      continue;
    }

    final urls = urlPattern
        .allMatches(trimmed)
        .map((match) => match.group(0)!)
        .toList(growable: false);
    if (urls.length == 1 &&
        trimmed == urls.first &&
        seenUrls.contains(urls.first)) {
      continue;
    }

    cleanedLines.add(trimmed);
    for (final url in urls) {
      seenUrls.add(url);
    }
  }

  if (cleanedLines.length.isEven) {
    final half = cleanedLines.length ~/ 2;
    var duplicatedBlock = true;
    for (var index = 0; index < half; index++) {
      if (cleanedLines[index] != cleanedLines[index + half]) {
        duplicatedBlock = false;
        break;
      }
    }
    if (duplicatedBlock) {
      cleanedLines.removeRange(half, cleanedLines.length);
    }
  }

  return cleanedLines.join('\n').trim();
}

String _cleanShareContext(String value, {int maxLength = 72}) {
  final cleaned = _sanitizeShareContext(value).trim();
  if (cleaned.isEmpty || _looksLikeJunkShareContext(cleaned)) {
    return '';
  }

  if (cleaned.length <= maxLength) {
    return cleaned;
  }

  return '${cleaned.substring(0, maxLength - 3).trimRight()}...';
}

String _sanitizeShareContext(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _looksLikeJunkShareContext(String value) {
  final normalized = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return true;
  }

  const junkValues = <String>{
    'n/a',
    'na',
    'none',
    'null',
    'unknown',
    'test',
    'testing',
    'demo',
    'sample',
    'example',
    'dummy',
    'placeholder',
    'tbd',
    'tbc',
    'todo',
    'temp',
    'temporary',
    'asdf',
    'lorem ipsum',
  };
  if (junkValues.contains(normalized)) {
    return true;
  }

  final junkPattern = RegExp(
    r'\b(test|testing|demo|sample|example|dummy|placeholder|lorem|ipsum)\b',
    caseSensitive: false,
  );
  return junkPattern.hasMatch(normalized);
}

String sanitizeVanCustomerPhoneNumber(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final hasLeadingPlus = trimmed.startsWith('+');
  final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) {
    return '';
  }

  return hasLeadingPlus ? '+$digitsOnly' : digitsOnly;
}

String normalizeVanCustomerPhoneNumberForMatch(String value) {
  final sanitized = sanitizeVanCustomerPhoneNumber(value);
  if (sanitized.isEmpty) {
    return '';
  }

  final digitsOnly = sanitized.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) {
    return '';
  }

  if (digitsOnly.startsWith('0044') && digitsOnly.length >= 6) {
    return '0${digitsOnly.substring(4)}';
  }

  if (digitsOnly.startsWith('44') && digitsOnly.length >= 11) {
    return '0${digitsOnly.substring(2)}';
  }

  if (digitsOnly.length == 10 && digitsOnly.startsWith('7')) {
    return '0$digitsOnly';
  }

  return digitsOnly;
}

Future<bool> copyRequestLink(String hostedRequestLink) async {
  final link = hostedRequestLink.trim();
  if (link.isEmpty) {
    return false;
  }

  await Clipboard.setData(ClipboardData(text: link));
  return true;
}

Future<ShareResult> shareRequestMessage(String message) {
  return SharePlus.instance.share(
    ShareParams(text: normalizeOutgoingRequestMessage(message)),
  );
}

String buildRequestEmailBody({
  required String link,
  String? jobTitle,
  String? address,
  bool exactPinRequested = false,
  bool exactPinRequestedAfterQuoteAccepted = false,
}) {
  final cleanedJobTitle = _cleanShareContext(jobTitle ?? '');
  final cleanedAddress = _cleanShareContext(address ?? '');
  final cleanedLink = link.trim();

  final lines = <String>[
    'Hi, please fill in these quick job questions so I can plan it properly.',
    '',
  ];

  if (exactPinRequested) {
    lines.add(
      "If you're at the pickup or drop-off point, you can also share the exact location pin on the form.",
    );
    lines.add('');
  } else if (exactPinRequestedAfterQuoteAccepted) {
    lines.add(
      'If you accept the quote, you may then be asked to share the exact pickup or drop-off pin.',
    );
    lines.add('');
  }

  if (cleanedJobTitle.isNotEmpty) {
    lines.add('Job: $cleanedJobTitle');
  }
  if (cleanedAddress.isNotEmpty) {
    lines.add('Address: $cleanedAddress');
  }
  lines.add('');
  lines.add('Open request:');
  lines.add(cleanedLink);
  lines.add('');
  lines.add('Thanks.');

  return lines.join('\n');
}

Future<bool> copyRequestMessage(String message) async {
  final normalizedMessage = normalizeOutgoingRequestMessage(message);
  if (normalizedMessage.isEmpty) {
    return false;
  }

  await Clipboard.setData(ClipboardData(text: normalizedMessage));
  return true;
}

Future<bool> textCustomerRequest({
  required String phoneNumber,
  required String message,
}) async {
  final sanitizedPhone = sanitizeVanCustomerPhoneNumber(phoneNumber);
  if (sanitizedPhone.isEmpty) {
    return false;
  }

  final normalizedMessage = normalizeOutgoingRequestMessage(message);
  final smsUri = Uri(
    scheme: 'sms',
    path: sanitizedPhone,
    queryParameters: <String, String>{'body': normalizedMessage},
  );
  return launchUrl(smsUri, mode: LaunchMode.externalApplication);
}

Future<bool> emailCustomerRequest({
  required String email,
  required String subject,
  required String message,
}) async {
  final cleanedEmail = email.trim();
  final normalizedSubject = subject.trim();
  final normalizedMessage = message.replaceAll('\r\n', '\n').trim();
  if (cleanedEmail.isEmpty) {
    debugPrint(
      '[RequestEmail] email= hasEmail=false subjectEncoded=${Uri.encodeComponent(normalizedSubject)} bodyLength=${normalizedMessage.length} launchSuccess=false error=empty_email',
    );
    return false;
  }

  final encodedSubject = Uri.encodeComponent(normalizedSubject);
  final encodedBody = Uri.encodeComponent(normalizedMessage);
  final mailto =
      'mailto:$cleanedEmail?subject=$encodedSubject&body=$encodedBody';
  final emailUri = Uri.parse(mailto);

  try {
    final launched = await launchUrl(
      emailUri,
      mode: LaunchMode.externalApplication,
    );
    debugPrint(
      '[RequestEmail] email=$cleanedEmail hasEmail=true subjectEncoded=$encodedSubject bodyLength=${normalizedMessage.length} launchSuccess=$launched error=(none)',
    );
    return launched;
  } catch (error) {
    debugPrint(
      '[RequestEmail] email=$cleanedEmail hasEmail=true subjectEncoded=$encodedSubject bodyLength=${normalizedMessage.length} launchSuccess=false error=$error',
    );
    return false;
  }
}

Future<bool> callCustomerPhone(String phoneNumber) async {
  return launchCustomerPhone(null, phoneNumber);
}

Future<bool> launchCustomerPhone(
  BuildContext? context,
  String? phoneNumber,
) async {
  final rawPhone = phoneNumber ?? '';
  final sanitizedPhone = sanitizeVanCustomerPhoneNumber(rawPhone);
  if (sanitizedPhone.isEmpty) {
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the phone dialer.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    debugPrint(
      '[PhoneDial] raw=$rawPhone cleaned=$sanitizedPhone success=false error=empty_phone',
    );
    return false;
  }

  final telUri = Uri(scheme: 'tel', path: sanitizedPhone);
  try {
    final launched = await launchUrl(
      telUri,
      mode: LaunchMode.externalApplication,
    );
    debugPrint(
      '[PhoneDial] raw=$rawPhone cleaned=$sanitizedPhone success=$launched error=(none)',
    );
    if (launched) {
      return true;
    }
  } catch (error) {
    debugPrint(
      '[PhoneDial] raw=$rawPhone cleaned=$sanitizedPhone success=false error=$error',
    );
  }

  await Clipboard.setData(ClipboardData(text: sanitizedPhone));
  if (context != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open dialer. Number copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  return false;
}
