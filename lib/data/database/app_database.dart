import 'package:camera_trap_app/data/database/database_schema.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Lifecycle and migration wrapper around the local SQLite database.
///
/// Use [AppDatabase.open] in the app, and [AppDatabase.openInMemory] in tests.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  Database get raw => _db;

  bool get isOpen => _db.isOpen;

  /// Opens (or creates) the persistent SQLite database on the device.
  static Future<AppDatabase> open({
    String? customPath,
    DatabaseFactory? factory,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath =
        customPath ??
        p.join(await dbFactory.getDatabasesPath(), DatabaseSchema.databaseName);

    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return AppDatabase._(db);
  }

  /// Opens an ephemeral in-memory database (ideal for unit tests).
  static Future<AppDatabase> openInMemory({DatabaseFactory? factory}) async {
    final dbFactory = factory ?? databaseFactory;
    final db = await dbFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute(DatabaseSchema.createCamerasTableSql);
    await db.execute(DatabaseSchema.createSettingsTableSql);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (var target = oldVersion + 1; target <= newVersion; target++) {
      final statements = DatabaseSchema.migrations[target];
      if (statements == null) continue;
      for (final sql in statements) {
        await db.execute(sql);
      }
    }
  }

  Future<void> close() => _db.close();
}
