import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// Mobile-only imports — guarded at runtime via kIsWeb checks.
// These will not compile on web unless imported conditionally.
import 'sharing_service_io.dart'
    if (dart.library.html) 'sharing_service_web.dart' as _platform;

/// Captures a widget (via its RepaintBoundary GlobalKey) as PNG bytes,
/// then shares or saves based on the action requested.
///
/// Web support:
///   - captureWidget: works on all platforms.
///   - shareImage: triggers a browser download on web.
///   - saveToGallery: triggers a browser download on web.
class SharingService {
  /// Renders the widget behind [key] to a PNG at [pixelRatio] density.
  static Future<Uint8List?> captureWidget(
    GlobalKey key, {
    double pixelRatio = 3.0,
  }) async {
    try {
      final boundary = key.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[SharingService] capture error: $e');
      return null;
    }
  }

  /// Shares via the system share sheet on mobile, or triggers a
  /// browser download on web.
  static Future<bool> shareImage(
    Uint8List bytes, {
    required String cardType,
    String text = 'Check out my progress on CS Simplified! 📚',
  }) async {
    try {
      return await _platform.shareImage(bytes,
          cardType: cardType, text: text);
    } catch (e) {
      debugPrint('[SharingService] share error: $e');
      return false;
    }
  }

  /// Saves the image to gallery on mobile, or downloads it on web.
  static Future<bool> saveToGallery(Uint8List bytes, {
    required String cardType,
  }) async {
    try {
      return await _platform.saveImage(bytes, cardType: cardType);
    } catch (e) {
      debugPrint('[SharingService] save error: $e');
      return false;
    }
  }
}
