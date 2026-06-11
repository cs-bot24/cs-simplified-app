// lib/screens/pdf/web_iframe_impl.dart
//
// Web implementation of createIframeElement using dart:html.
// Only compiled on web via conditional import in pdf_web_panels.dart.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Creates a dart:html IFrameElement pointing at [url].
html.IFrameElement createIframeElement(String url) {
  return html.IFrameElement()
    ..src = url
    ..style.border = 'none'
    ..style.width  = '100%'
    ..style.height = '100%'
    ..allowFullscreen = true
    ..setAttribute('allow', 'fullscreen');
}
