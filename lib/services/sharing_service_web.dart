// lib/services/sharing_service_web.dart
// Web platform implementation of share + save — triggers a browser download.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> shareImage(
  Uint8List bytes, {
  required String cardType,
  String text = '',
}) async {
  return saveImage(bytes, cardType: cardType);
}

Future<bool> saveImage(
  Uint8List bytes, {
  required String cardType,
}) async {
  final blob   = html.Blob([bytes], 'image/png');
  final url    = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', 'cs_simplified_$cardType.png')
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}
