import 'package:flutter/foundation.dart';

@immutable
class VanInvoiceReplyAnswer {
  const VanInvoiceReplyAnswer({
    required this.question,
    required this.answer,
    this.note = '',
  });

  final String question;
  final String answer;
  final String note;
}

Set<String> buildSuggestedInvoiceExtraKeys({
  Iterable<VanInvoiceReplyAnswer> checklistResponses =
      const <VanInvoiceReplyAnswer>[],
  Iterable<VanInvoiceReplyAnswer> customQuestionResponses =
      const <VanInvoiceReplyAnswer>[],
  String jobTitle = '',
  String jobDescription = '',
  String additionalNotes = '',
  String quoteNotes = '',
  String quoteMessage = '',
  String estimatedMiles = '',
  bool hasMileageCharge = false,
  bool allowCustomerReplySuggestions = true,
}) {
  if (!allowCustomerReplySuggestions) {
    return <String>{};
  }

  final suggestions = <String>{};
  final contextText = _normalize(
    [
      jobTitle,
      jobDescription,
      additionalNotes,
      quoteNotes,
      quoteMessage,
    ].join(' '),
  );

  for (final response in checklistResponses) {
    final question = _normalize(response.question);
    final answer = _normalize(response.answer);
    final note = _normalize(response.note);
    final responseText = '$question $answer $note'.trim();

    if (_isLoadingHelpSignal(question, answer, note)) {
      suggestions.add('helper');
    }

    if (_isStairsAccessSignal(question, answer, note)) {
      suggestions.add('stairs');
    }

    if (_isCollectionDeliverySignal(responseText)) {
      suggestions.add('collection_delivery');
    }
  }

  for (final response in customQuestionResponses) {
    final responseText = _normalize(
      '${response.question} ${response.answer} ${response.note}',
    );

    if (_containsAny(responseText, _collectionDeliveryKeywords)) {
      suggestions.add('collection_delivery');
    }
    if (_containsAny(responseText, _helperKeywords)) {
      suggestions.add('helper');
    }
    if (_containsAny(responseText, _stairsKeywords)) {
      suggestions.add('stairs');
    }
  }

  if (estimatedMiles.trim().isNotEmpty ||
      hasMileageCharge ||
      _containsAny(contextText, _mileageKeywords)) {
    suggestions.add('mileage');
  }

  if (_containsAny(contextText, _collectionDeliveryKeywords)) {
    suggestions.add('collection_delivery');
  }

  return suggestions;
}

/// Maps a line-item description to a quick-extra key when the text clearly matches one.
String? canonicalizeVanInvoiceExtraKey(String value) {
  final normalized = _normalize(value);
  if (normalized.isEmpty) {
    return null;
  }

  if (normalized == 'custom item') {
    return 'custom';
  }
  if (_containsCollectionDelivery(normalized)) {
    return 'collection_delivery';
  }
  if (_containsAny(normalized, _waitingTimeKeywords)) {
    return 'waiting_time';
  }
  if (_containsAny(normalized, _stairsKeywords)) {
    return 'stairs';
  }
  if (_containsAny(normalized, _helperKeywords)) {
    return 'helper';
  }
  if (_containsAny(normalized, _mileageKeywords)) {
    return 'mileage';
  }

  return null;
}

const List<String> _helperKeywords = <String>[
  'help loading',
  'loading help',
  'help loading/unloading',
  'help loading unloading',
  'loading/unloading',
  'loading unloading',
  'loading and unloading',
  'loading helper',
  'extra helper',
  'helper',
  'extra person',
  'two people',
  'man and van',
];

const List<String> _waitingTimeKeywords = <String>['waiting time'];

const List<String> _stairsKeywords = <String>[
  'stairs',
  'stair',
  'stairs/access',
  'stairs access',
  'upstairs',
  'no lift',
  'lift unavailable',
  'access charge',
  'steps',
  'access difficulty',
  'access issue',
  'difficult access',
];

const List<String> _collectionDeliveryKeywords = <String>[
  'collection',
  'delivery',
  'courier',
  'pickup',
  'pick up',
  'drop off',
  'drop-off',
  'removal',
];

const List<String> _mileageKeywords = <String>['mileage', 'mile'];

String _normalize(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}

bool _containsAny(String text, List<String> keywords) {
  if (text.isEmpty) {
    return false;
  }
  for (final keyword in keywords) {
    if (text.contains(keyword)) {
      return true;
    }
  }
  return false;
}

bool _containsCollectionDelivery(String text) {
  return text.contains('collection') && text.contains('delivery');
}

bool _looksAffirmative(String value) {
  final normalized = _normalize(value);
  if (normalized.isEmpty) {
    return false;
  }

  const exactMatches = <String>{
    'yes',
    'y',
    'true',
    '1',
    'needed',
    'need',
    'required',
    'request',
    'requested',
    'yes please',
    'please',
    'yep',
    'yeah',
    'absolutely',
    'sure',
  };
  if (exactMatches.contains(normalized)) {
    return true;
  }

  return normalized.contains('yes') ||
      normalized.contains('need') ||
      normalized.contains('required') ||
      normalized.contains('requested') ||
      normalized.contains('help');
}

bool _isLoadingHelpSignal(String question, String answer, String note) {
  final text = '$question $answer $note'.trim();
  if (text.isEmpty) {
    return false;
  }

  final mentionsLoadingHelp =
      text.contains('help loading') ||
      text.contains('loading help') ||
      text.contains('help loading/unloading') ||
      text.contains('help loading unloading') ||
      text.contains('loading/unloading') ||
      text.contains('loading unloading') ||
      text.contains('loading and unloading') ||
      text.contains('extra helper') ||
      text.contains('helper');
  if (!mentionsLoadingHelp) {
    return false;
  }

  return _looksAffirmative(answer) ||
      _containsAny(note, _helperKeywords) ||
      _containsAny(answer, _helperKeywords);
}

bool _isStairsAccessSignal(String question, String answer, String note) {
  final text = '$question $answer $note'.trim();
  if (text.isEmpty) {
    return false;
  }

  final mentionsStairs =
      text.contains('stairs') ||
      text.contains('stair') ||
      text.contains('access') ||
      text.contains('lift');
  if (!mentionsStairs) {
    return false;
  }

  return _looksAffirmative(answer) ||
      _containsAny(answer, _stairsKeywords) ||
      _containsAny(note, _stairsKeywords);
}

bool _isCollectionDeliverySignal(String text) {
  if (text.isEmpty) {
    return false;
  }

  return _containsAny(text, _collectionDeliveryKeywords);
}
