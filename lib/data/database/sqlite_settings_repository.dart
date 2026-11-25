import 'package:camera_trap_app/data/database/app_database.dart';
import 'package:camera_trap_app/data/database/database_schema.dart';
import 'package:camera_trap_app/data/models/theme_preference.dart';
import 'package:camera_trap_app/data/settings_repository.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed implementation of [SettingsRepository].
///
/// Ready to replace [InMemorySettingsRepository] in `main.dart` whenever you
/// decide to wire persistence into the app.
class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository(this._database);

  static const String _themePreferenceKey = 'theme_preference';

  final AppDatabase _database;

  Database get _db => _database.raw;

  @override
  Future<ThemePreference> loadThemePreference() async {
    final value = await getString(_themePreferenceKey);
    if (value == null) return ThemePreference.system;
    return ThemePreference.values
            .where((e) => e.name == value)
            .firstOrNull ??
        ThemePreference.system;
  }

  @override
  Future<void> saveThemePreference(ThemePreference preference) =>
      setString(_themePreferenceKey, preference.name);

  /// Generic key-value helpers for any future app-level settings.
  Future<String?> getString(String key) async {
    final rows = await _db.query(
      DatabaseSchema.settingsTable,
      columns: [DatabaseSchema.colSettingValue],
      where: '${DatabaseSchema.colSettingKey} = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first[DatabaseSchema.colSettingValue] as String?;
  }

  Future<void> setString(String key, String value) async {
    await _db.insert(
      DatabaseSchema.settingsTable,
      {
        DatabaseSchema.colSettingKey: key,
        DatabaseSchema.colSettingValue: value,
        DatabaseSchema.colUpdatedAtMs: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> remove(String key) => _db.delete(
    DatabaseSchema.settingsTable,
    where: '${DatabaseSchema.colSettingKey} = ?',
    whereArgs: [key],
  );
}
