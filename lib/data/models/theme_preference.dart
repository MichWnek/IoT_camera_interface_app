/// Which theme the user picked. Kept separate from Flutter's `ThemeMode`
/// so the data layer doesn't depend on UI code, and so the names match
/// what the app calls them.
enum ThemePreference {
  /// Follow the phone's light/dark setting.
  system,

  /// High contrast light theme for daylight.
  day,

  /// Dim red theme that preserves night vision.
  night,
}
