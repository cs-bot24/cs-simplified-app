// lib/providers/ai_provider_io.dart
// Mobile implementation — reads image bytes from dart:io File.
// Imported by ai_provider.dart on non-web platforms via:
//   import 'ai_provider_io.dart' if (dart.library.html) 'ai_provider_web.dart'

import 'dart:io';
import 'package:flutter/foundation.dart' show Uint8List;

Future<Uint8List> readImageBytes(dynamic file) async {
  return await (file as File).readAsBytes();
}

String getImagePath(dynamic file) {
  return (file as File).path;
}
