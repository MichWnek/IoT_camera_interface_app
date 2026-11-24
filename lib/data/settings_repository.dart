import 'package:camera_trap_app/data/models/theme_preference.dart';

/// Where user settings are kept.
///
/// The app only depends on this interface, so a persistent implementation
/// (local database or shared preferences) can replace the in-memory one
/// without changing any screen or cubit.
abstract interface class SettingsRepository {
  Future<ThemePreference> loadThemePreference();

  Future<void> saveThemePreference(ThemePreference preference);
}

/// Keeps settings for as long as the app runs; they reset on restart.
// TODO: replace with a persistent implementation once the local database lands.
class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository([this._themePreference = ThemePreference.system]);

  ThemePreference _themePreference;

  @override
  Future<ThemePreference> loadThemePreference() async => _themePreference;

  @override
  Future<void> saveThemePreference(ThemePreference preference) async {
    _themePreference = preference;
  }
}
