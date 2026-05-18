String? cleanVanNoteText(String? note, {String postcode = ''}) {
  final normalizedNote = _normalizeNoteText(note);
  final normalizedPostcode = _normalizePostcodeText(postcode);

  if (normalizedNote.isEmpty) {
    return null;
  }

  if (normalizedPostcode.isEmpty) {
    return normalizedNote;
  }

  final cleaned = _removePostcodeFromNote(normalizedNote, normalizedPostcode);
  return cleaned.isEmpty ? null : cleaned;
}

String _normalizeNoteText(String? note) {
  return note?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
}

String _normalizePostcodeText(String postcode) {
  return postcode.replaceAll(RegExp(r'\s+'), '').toUpperCase().trim();
}

String _removePostcodeFromNote(String note, String postcode) {
  final compactPostcode = postcode.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (compactPostcode.isEmpty) {
    return note;
  }

  final postcodePattern = RegExp(
    r'(?<![A-Z0-9])' +
        compactPostcode.split('').map(RegExp.escape).join(r'[\s\-]*') +
        r'(?![A-Z0-9])',
    caseSensitive: false,
  );

  final cleaned = note.replaceAll(postcodePattern, ' ');
  return cleaned
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s+([,.;:!?])'), r'$1')
      .trim();
}
