import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// Non-web imports — guarded at runtime.
// sharing_service_io.dart covers Android/iOS AND Windows desktop (it
// branches internally on Platform.isWindows — see that file's header
// comment, desktop audit Part 3 / implementation Phase 3A). This shim
// will not compile on web unless imported conditionally.
import 'sharing_service_io.dart'
    if (dart.library.html) 'sharing_service_web.dart' as _platform;

/// Captures a widget (via its RepaintBoundary GlobalKey) as PNG bytes,
/// then shares or saves based on the action requested.
///
/// Platform behavior:
///   - captureWidget: works on all platforms.
///   - shareImage: system share sheet on Android/iOS; browser download on
///     web; falls back to the save flow on Windows (no share-sheet wired
///     up there yet).
///   - saveToGallery: photo gallery on Android/iOS; browser download on
///     web; native Save File dialog on Windows.
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
