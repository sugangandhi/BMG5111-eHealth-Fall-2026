import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the Home dashboard displays the compact Grid View
/// instead of the default 12-card App Switcher carousel.
class DashboardLayoutPreferences {
  static const String gridViewKey = 'dashboard_grid_view';

  /// Returns `true` when compact Grid View should replace the carousel on Home.
  static Future<bool> isGridViewEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(gridViewKey) ?? false;
  }

  /// Stores the user's preferred Home dashboard layout mode.
  static Future<void> setGridViewEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(gridViewKey, enabled);
  }
}
