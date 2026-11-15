// Unit tests for parseReleaseNotes.
//
// NOT RUN by the author: the Flutter/Dart SDK was not available in the
// authoring environment. Run with `flutter test test/release_notes_test.dart`.
import 'package:flutter_test/flutter_test.dart';
import 'package:cs_simplified/core/release_notes.dart';

void main() {
  group('parseReleaseNotes', () {
    test('returns the lines of a normal list, in order', () {
      expect(parseReleaseNotes(['A', 'B', 'C']), ['A', 'B', 'C']);
    });

    test('missing or wrong-type field gives an empty list', () {
      expect(parseReleaseNotes(null), isEmpty);
      expect(parseReleaseNotes('text'), isEmpty);
      expect(parseReleaseNotes({'a': 1}), isEmpty);
    });

    test('skips blanks and non-strings, and tidies whitespace', () {
      expect(parseReleaseNotes(['  ', 5, null, '  New   thing  ']), ['New thing']);
    });

    test('limits the number of lines and their length', () {
      final many = [for (var i = 0; i < 10; i++) 'n$i'];
      expect(parseReleaseNotes(many).length, 5);
      expect(parseReleaseNotes(['x' * 500]).single.length, 160);
    });
  });
}
