// lib/widgets/mermaid_diagram.dart
//
// Platform-adaptive Mermaid diagram renderer.
//
// Import this file — never the platform-specific files directly.
//
// Dispatch:
//   dart.library.html  → mermaid_diagram_web.dart    (Flutter Web)
//   dart.library.io    → mermaid_diagram_mobile.dart (Android / iOS)
//   (neither)          → mermaid_diagram_stub.dart   (tests / unsupported)
//
// All three files export the same public API:
//   class MermaidDiagram extends StatefulWidget {
//     const MermaidDiagram({required String source, required bool isDark});
//   }

export 'mermaid_diagram_stub.dart'
    if (dart.library.html) 'mermaid_diagram_web.dart'
    if (dart.library.io) 'mermaid_diagram_mobile.dart';
