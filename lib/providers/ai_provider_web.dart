// lib/providers/ai_provider_web.dart
// Web implementation — dart:io is not available.
// On web, images come as Uint8List from file_picker/image_picker.
// askWithImage() is never called on web — askWithImageBytes() is used instead.
// These stubs exist only to satisfy the conditional import.

import 'package:flutter/foundation.dart' show Uint8List;

Future<Uint8List> readImageBytes(dynamic file) async {
  // Never called on web — askWithImageBytes() is used instead.
  throw UnsupportedError('readImageBytes not supported on web.');
}

String getImagePath(dynamic file) {
  // Never called on web.
  throw UnsupportedError('getImagePath not supported on web.');
}
