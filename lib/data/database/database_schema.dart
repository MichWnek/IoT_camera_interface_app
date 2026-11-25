/// Central definition of SQLite tables, columns, and schema migrations.
///
/// Keeping all table/column names and DDL here makes it straightforward to
/// rename columns, add new fields (e.g. GPS altitude, BLE RSSI history), or
/// introduce new tables in future schema versions.
abstract final class DatabaseSchema {
  static const String databaseName = 'camera_trap_app.db';
  static const int version = 1;

  static const String camerasTable = 'cameras';
  static const String settingsTable = 'app_settings';

  // Columns for `cameras`
  static const String colId = 'id';
  static const String colName = 'name';
  static const String colBleMac = 'ble_mac';

  // Last known DeviceStatus fields (all nullable if never connected)
  static const String colBatteryPercent = 'battery_percent';
  static const String colSdFreeGb = 'sd_free_gb';
  static const String colIsOnline = 'is_online';
  static const String colLastSeenMs = 'last_seen_ms';

  // Last known CameraConfig fields (nullable until configured/read)
  static const String colAiThreshold = 'ai_threshold';
  static const String colPirThreshold = 'pir_threshold';
  static const String colConfigUpdatedAtMs = 'config_updated_at_ms';

  // Extensible status & future GPS / field-work metadata
  static const String colStatusLabel = 'status_label';
  static const String colLatitude = 'latitude';
  static const String colLongitude = 'longitude';
  static const String colLocationUpdatedAtMs = 'location_updated_at_ms';
  static const String colNotes = 'notes';
  static const String colExtraJson = 'extra_json';

  // Record audit timestamps
  static const String colCreatedAtMs = 'created_at_ms';
  static const String colUpdatedAtMs = 'updated_at_ms';

  // Columns for `app_settings`
  static const String colSettingKey = 'key';
  static const String colSettingValue = 'value';

  static const String createCamerasTableSql = '''
CREATE TABLE $camerasTable (
  $colId TEXT PRIMARY KEY,
  $colName TEXT NOT NULL,
  $colBleMac TEXT NOT NULL UNIQUE,
  $colBatteryPercent INTEGER CHECK ($colBatteryPercent IS NULL OR ($colBatteryPercent >= 0 AND $colBatteryPercent <= 100)),
  $colSdFreeGb REAL CHECK ($colSdFreeGb IS NULL OR $colSdFreeGb >= 0),
  $colIsOnline INTEGER CHECK ($colIsOnline IS NULL OR $colIsOnline IN (0, 1)),
  $colLastSeenMs INTEGER,
  $colAiThreshold REAL CHECK ($colAiThreshold IS NULL OR ($colAiThreshold >= 0.0 AND $colAiThreshold <= 1.0)),
  $colPirThreshold REAL CHECK ($colPirThreshold IS NULL OR ($colPirThreshold >= 0.0 AND $colPirThreshold <= 3.3)),
  $colConfigUpdatedAtMs INTEGER,
  $colStatusLabel TEXT,
  $colLatitude REAL CHECK ($colLatitude IS NULL OR ($colLatitude >= -90.0 AND $colLatitude <= 90.0)),
  $colLongitude REAL CHECK ($colLongitude IS NULL OR ($colLongitude >= -180.0 AND $colLongitude <= 180.0)),
  $colLocationUpdatedAtMs INTEGER,
  $colNotes TEXT,
  $colExtraJson TEXT,
  $colCreatedAtMs INTEGER NOT NULL,
  $colUpdatedAtMs INTEGER NOT NULL
)
''';

  static const String createSettingsTableSql = '''
CREATE TABLE $settingsTable (
  $colSettingKey TEXT PRIMARY KEY,
  $colSettingValue TEXT NOT NULL,
  $colUpdatedAtMs INTEGER NOT NULL
)
''';

  /// Ordered migration steps keyed by target schema version.
  ///
  /// Example when moving to version 2:
  /// ```dart
  /// 2: [
  ///   'ALTER TABLE $camerasTable ADD COLUMN altitude_m REAL',
  /// ],
  /// ```
  static const Map<int, List<String>> migrations = {};
}
