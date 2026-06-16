// lib/services/sharing_service_io.dart
// Mobile (Android/iOS) platform implementation of share + save.

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';

Future<bool> shareImage(
  Uint8List bytes, {
  required String cardType,
  String text = 'Check out my progress on CS Simplified! 📚',
}) async {
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
  await Gal.putImageBytes(bytes, name: 'cs_simplified_$cardType');
  return true;
}
