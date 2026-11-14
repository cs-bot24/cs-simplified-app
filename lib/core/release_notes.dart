// Parses the optional "release_notes" list from GET /version.
//
// NOT RUN by the author: the Flutter/Dart SDK was not available in the
// authoring environment. See test/release_notes_test.dart.

/// Returns at most [maxItems] short, non-empty lines. Anything that is not a
/// list of strings (missing field, older backend, bad data) gives an empty
/// list, and the update dialog then shows its normal generic sentence.
List<String> parseReleaseNotes(
  dynamic raw, {
  int maxItems = 5,
  int maxChars = 160,
}) {
  if (raw is! List) return const [];
  final out = <String>[];
  for (final item in raw) {
    if (item is! String) continue;
    final text = item.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) continue;
    out.add(text.length > maxChars ? text.substring(0, maxChars) : text);
    if (out.length >= maxItems) break;
  }
  return out;
}
