// lib/screens/pdf/web_iframe_stub.dart
//
// Mobile stub for the dart:html iframe factory.
// Returns a plain Object so the type checker is satisfied;
// this function is never called at runtime on mobile because
// all call sites are guarded with kIsWeb.

Object createIframeElement(String url) {
  throw UnsupportedError('createIframeElement is not available on mobile.');
}
