// Widget smoke test for CS Simplified.
//
// The original counter-app template referenced `MyApp`, a class that no
// longer exists anywhere in this codebase (see lib/main.dart). This test
// instead exercises the real production root widget, `CsSimplifiedApp`.
//
// `CsSimplifiedApp`'s `home` is `_AppBootstrap` -> `SplashScreen`, whose
// `initState()` starts a 2-second delayed navigation that (for a
// logged-out session) ends with a call to `VersionCheck.check()`, which
// makes a real HTTP request via package:http. Two things make that unsafe
// to leave alone in a widget test:
//
//   1. A `Timer` (including one from `Future.delayed`) that is still
//      pending when a `testWidgets` body finishes causes flutter_test to
//      fail the test with "A Timer is still pending even after the widget
//      tree was disposed."
//   2. A real network call inside `flutter_test`'s fake-async test zone
//      is exactly the kind of external, non-deterministic dependency a
//      unit test should not have (slow/flaky depending on whatever
//      network the test happens to run on, and it would otherwise hit a
//      live backend from CI).
//
// So this test blocks all real network I/O at the dart:io `HttpClient`
// level (via `HttpOverrides`, scoped to this test only) and then lets
// fake time advance far enough for SplashScreen's delayed navigation to
// run to completion. That proves the entire real provider tree, theming,
// and startup navigation flow construct and render without throwing --
// without touching production code and without any real network
// dependency.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cs_simplified/main.dart';
import 'package:cs_simplified/providers/theme_provider.dart';
import 'package:cs_simplified/screens/auth/login_screen.dart';

/// Fails every request immediately instead of attempting a real
/// connection. Any member not explicitly overridden below falls through
/// to [noSuchMethod], which also fails fast -- so nothing reachable from
/// this test can perform real network I/O.
class _NoNetworkHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) => _fail();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => _fail();

  Future<HttpClientRequest> _fail() => Future<HttpClientRequest>.error(
        const SocketException('Network access is disabled in widget tests'),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'CsSimplifiedApp builds and boots to the login screen for a logged-out session',
    (WidgetTester tester) async {
      await HttpOverrides.runZoned<Future<void>>(() async {
        // Mirrors what main() passes to runApp(), minus the
        // SharedPreferences-backed loadTheme() call: ThemeProvider's
        // default (ThemeMode.system) is enough to prove the widget tree
        // builds, and calling loadTheme() would hit a plugin channel this
        // test doesn't need.
        final themeProvider = ThemeProvider();

        await tester.pumpWidget(CsSimplifiedApp(themeProvider: themeProvider));

        // First frame: the splash screen (the app's real `home` widget)
        // should render immediately.
        expect(find.text('CS Simplified'), findsOneWidget);
        expect(find.text('Your academic learning hub'), findsOneWidget);

        // Let SplashScreen's real 2-second delayed navigation run to
        // completion. With no stored session, AuthProvider.loadFromStorage()
        // resolves to "logged out" (an in-memory check only, no plugin
        // calls), and the blocked VersionCheck HTTP call fails fast and is
        // swallowed by SplashScreen's existing error handling, exactly as
        // it would be offline on a real device.
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // Confirms real navigation actually executed: a logged-out
        // session lands on the login screen.
        expect(find.byType(LoginScreen), findsOneWidget);
      }, createHttpClient: (SecurityContext? context) => _NoNetworkHttpClient());
    },
  );
}
