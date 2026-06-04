/// admin_requests_screen.dart
///
/// Legacy shim — kept so existing imports compile without changes.
/// All functionality is now in AdminMaterialRequestsScreen.
library;

import 'package:flutter/material.dart';
import 'admin_material_requests_screen.dart';

/// Alias for AdminMaterialRequestsScreen.
/// Any code that still imports or navigates to AdminRequestsScreen
/// will get the new implementation automatically.
class AdminRequestsScreen extends StatelessWidget {
  const AdminRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const AdminMaterialRequestsScreen();
}
