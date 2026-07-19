// lib/core/breakpoints.dart
//
// Centralized responsive breakpoints (desktop Phase 2, Task 15).
//
// Before this file, home_screen.dart was the only place with a desktop
// breakpoint (a private `_kDesktopBreakpoint = 900.0`). As Phase 2 adds
// responsive layout logic to more screens (Browse, PDF, AI Tutor, etc.),
// each one needs the same threshold — this file is the single source of
// truth so they don't drift apart over time.
//
// Deliberately small — four constants and two helpers, not a full
// responsive-framework abstraction. See the desktop audit / Phase 2 spec:
// "do not over-engineer this."

import 'package:flutter/widgets.dart';

class Breakpoints {
  Breakpoints._();

  /// Below this: phone-style single-column layouts.
  static const double mobile = 600;

  /// Tablet / small-window desktop — still narrow enough that a
  /// NavigationRail-style persistent sidebar doesn't yet make sense.
  static const double tablet = 900;

  /// home_screen.dart's existing threshold — where the bottom
  /// NavigationBar switches to a NavigationRail. Kept identical to the
  /// value already shipping today so this refactor changes no behavior,
  /// only where the number lives.
  static const double desktop = 900;

  /// Comfortably wide desktop — enough room for 3–4 column grids, a
  /// PDF + bookmarks split view, or an AI chat + context split view.
  static const double wideDesktop = 1280;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;

  static bool isWideDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= wideDesktop;

  /// Centers [child] within [maxWidth] on desktop so single-column content
  /// (a list, a form, a reading column) doesn't stretch edge-to-edge on a
  /// maximized window. No-op below the desktop breakpoint.
  ///
  /// Phase 2A: factored out here because by this phase three different
  /// screens (Home, Browse/courses, and now Exam Prep) wanted the exact
  /// same `Center(ConstrainedBox(...))` pattern — worth a shared helper
  /// rather than a fourth copy-paste. home_screen.dart and
  /// courses_screen.dart's already-working, already-reviewed versions of
  /// this were left as-is rather than retrofitted to call this, to avoid
  /// re-touching (and re-introducing risk into) code that's already
  /// verified-by-review — this is for new call sites going forward.
  static Widget centered(BuildContext context, Widget child,
      {double maxWidth = 900}) {
    if (!isDesktop(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
