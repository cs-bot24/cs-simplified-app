import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'dart:io';

class SharingService {
  static Future<Uint8List?> captureWidget(
    GlobalKey key, {
    double pixelRatio = 3.0,
  }) async {
    try {
      final boundary = key.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[SharingService] capture error: $e');
      return null;
    }
  }

  static Future<bool> shareImage(
    Uint8List bytes, {
    required String cardType,
    String text = 'Check out my progress on CS Simplified! 📚',
  }) async {
    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/cs_share_$cardType.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text,
      );
      return true;
    } catch (e) {
      debugPrint('[SharingService] share error: $e');
      return false;
    }
  }

  static Future<bool> saveToGallery(Uint8List bytes, {
    required String cardType,
  }) async {
    try {
      await Gal.putImageBytes(bytes, name: 'cs_simplified_$cardType');
      return true;
    } catch (e) {
      debugPrint('[SharingService] save error: $e');
      return false;
    }
  }
}
