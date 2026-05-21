// core/constants.dart — App-wide constants

class AppConstants {
  // ── API ────────────────────────────────────────────────────────────────────
  // Change this to your deployed API URL when you go live
  static const String baseUrl = 'https://cs-api-cqve.onrender.com/api/v1';
  // For physical device on same WiFi network use your PC's local IP:
  // static const String baseUrl = 'http://192.168.x.x:8000/api/v1';

  // ── App ────────────────────────────────────────────────────────────────────
  static const String appName    = 'CS Simplified';
  static const String appTagline = 'Your academic learning hub';

  // ── Storage keys ───────────────────────────────────────────────────────────
  static const String tokenKey    = 'auth_token';
  static const String userKey     = 'auth_user';

  // ── Colors ─────────────────────────────────────────────────────────────────
  static const int primaryColorValue   = 0xFF1A3C6E;  // Deep blue
  static const int secondaryColorValue = 0xFF2E6DA4;  // Medium blue
  static const int accentColorValue    = 0xFFE8F0FE;  // Soft blue background
  static const int textDarkValue       = 0xFF1A1A2E;
  static const int textLightValue      = 0xFF6B7280;
  static const int successColorValue   = 0xFF10B981;
  static const int errorColorValue     = 0xFFEF4444;

  static const String appVersion = '1.0.0';

}
