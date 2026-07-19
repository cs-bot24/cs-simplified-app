// lib/services/sharing_service_io.dart
// Mobile (Android/iOS) + Windows desktop platform implementation of
// share + save. This file is selected for every non-web platform (see
// the conditional import in sharing_service.dart) — Windows is handled
// here via a runtime Platform.isWindows branch rather than a separate
// conditional-import target, since Dart's conditional imports only
// distinguish by library availability (e.g. dart.library.html), not by
// target platform.
//
// Desktop audit Part 3 / Part 11 reference: `gal` (Android/iOS gallery
// saver) has no Windows implementation at all, so Windows gets its own
// save path using `file_picker`'s native Save File dialog instead.

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:file_picker/file_picker.dart';

Future<bool> shareImage(
  Uint8List bytes, {
  required String cardType,
  String text = 'Check out my progress on CS Simplified! 📚',
}) async {
  if (Platform.isWindows) {
    // No system share-sheet equivalent is wired up for Windows in this
    // app's current dependency set. Falling back to the same "share ==
    // save" behavior the web implementation already uses
    // (sharing_service_web.dart) rather than inventing new UX here.
    return saveImage(bytes, cardType: cardType);
  }
  final dir  = await getTemporaryDirectory();
  final file = File('${dir.path}/cs_share_$cardType.png');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'image/png')],
    text: text,
  );
  return true;
}

Future<bool> saveImage(
  Uint8List bytes, {
  required String cardType,
}) async {
  if (Platform.isWindows) {
    return _saveImageWindows(bytes, cardType: cardType);
  }
  await Gal.putImageBytes(bytes, name: 'cs_simplified_$cardType');
  return true;
}

/// Windows save path: opens the native Save File dialog via `file_picker`
/// (already a project dependency) and writes the PNG bytes to the chosen
/// location. `file_picker`'s desktop `saveFile()` returns a destination
/// path rather than writing bytes itself (unlike its mobile/web behavior),
/// so the write is done explicitly here via dart:io.
Future<bool> _saveImageWindows(
  Uint8List bytes, {
  required String cardType,
}) async {
  try {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save achievement image',
      fileName: 'cs_simplified_$cardType.png',
    );
    if (path == null) return false; // user cancelled the dialog
    await File(path).writeAsBytes(bytes);
    return true;
  } catch (e) {
    return false;
  }
}
