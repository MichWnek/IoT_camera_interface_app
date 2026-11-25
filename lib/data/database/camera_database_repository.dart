import 'dart:convert';

import 'package:camera_trap_app/data/database/app_database.dart';
import 'package:camera_trap_app/data/database/camera_record.dart';
import 'package:camera_trap_app/data/database/database_schema.dart';
import 'package:camera_trap_app/data/models/camera_config.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';
import 'package:camera_trap_app/data/models/device_status.dart';
import 'package:sqflite/sqflite.dart';

/// Thrown when a camera is saved with a BLE address that a *different* camera
/// already uses. The UI can show "This camera is already added".
class DuplicateBleMacException implements Exception {
  const DuplicateBleMacException(this.bleMac);

  final String bleMac;

  @override
  String toString() =>
      'DuplicateBleMacException: $bleMac is already used by another camera';
}

/// CRUD and targeted update operations for the `cameras` SQLite table.
///
/// Writes never use SQLite's `REPLACE`: it deletes the old row before
/// inserting, which drops columns the caller didn't pass, silently deletes
/// whichever camera owned a duplicate MAC, and would fire `ON DELETE CASCADE`
/// on any future table that references cameras.
class CameraDatabaseRepository {
  CameraDatabaseRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.raw;

  /// Returns all stored cameras sorted alphabetically by name.
  Future<List<CameraRecord>> getAll() async {
    final rows = await _db.query(
      DatabaseSchema.camerasTable,
      orderBy: '${DatabaseSchema.colName} ASC',
    );
    return rows.map(CameraRecord.fromMap).toList();
  }

  /// Convenience helper returning existing [CameraTrap] domain models.
  Future<List<CameraTrap>> getAllCameraTraps() async {
    final records = await getAll();
    return records.map((r) => r.toCameraTrap()).toList();
  }

  Future<CameraRecord?> getById(String id) async {
    final rows = await _db.query(
      DatabaseSchema.camerasTable,
      where: '${DatabaseSchema.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CameraRecord.fromMap(rows.first);
  }

  Future<CameraRecord?> getByBleMac(String bleMac) async {
    final rows = await _db.query(
      DatabaseSchema.camerasTable,
      where: '${DatabaseSchema.colBleMac} = ?',
      whereArgs: [CameraRecord.normalizeBleMac(bleMac)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CameraRecord.fromMap(rows.first);
  }

  /// Saves the full [record]: every column is written from it, so a `null`
  /// field clears that column. `createdAt` of an existing camera is kept.
  ///
  /// To save only what a [CameraTrap] knows about (name, MAC, status) without
  /// touching config, location, notes, etc., use [saveCameraTrap].
  ///
  /// Throws [DuplicateBleMacException] if another camera has the same MAC.
  Future<void> upsert(CameraRecord record) =>
      _db.transaction((txn) => _upsertRecord(txn, record, DateTime.now()));

  /// Saves multiple full records in a single transaction. If any of them
  /// fails (e.g. [DuplicateBleMacException]), none are saved.
  Future<void> upsertAll(List<CameraRecord> records) =>
      _db.transaction((txn) async {
        final now = DateTime.now();
        for (final record in records) {
          await _upsertRecord(txn, record, now);
        }
      });

  /// Saves the name, MAC and status of [trap], adding the camera if it is
  /// new. Everything else stored for an existing camera (last config,
  /// location, notes, extra, createdAt) is left untouched.
  ///
  /// Throws [DuplicateBleMacException] if another camera has the same MAC.
  Future<void> saveCameraTrap(CameraTrap trap) => _db.transaction((txn) async {
    final now = DateTime.now();
    await _updateOrInsert(
      txn,
      id: trap.id,
      bleMac: trap.bleMac,
      updateValues: {
        DatabaseSchema.colName: trap.name,
        DatabaseSchema.colBleMac: CameraRecord.normalizeBleMac(trap.bleMac),
        ..._statusColumns(trap.status),
        DatabaseSchema.colUpdatedAtMs: now.millisecondsSinceEpoch,
      },
      insertValues: CameraRecord.fromCameraTrap(
        trap,
        createdAt: now,
        updatedAt: now,
      ).toMap(),
    );
  });

  Future<int> updateName(String id, String name) =>
      _updateFields(id, {DatabaseSchema.colName: name});

  /// Updates the last known [DeviceStatus] (battery, SD space, online state).
  /// Pass `null` to clear the stored status.
  Future<int> updateStatus(String id, DeviceStatus? status) =>
      _updateFields(id, _statusColumns(status));

  /// Updates the last known [CameraConfig] (AI & PIR thresholds).
  Future<int> updateLastConfig(
    String id,
    CameraConfig? config, {
    DateTime? updatedAt,
  }) => _updateFields(id, {
    DatabaseSchema.colAiThreshold: config?.aiThreshold,
    DatabaseSchema.colPirThreshold: config?.pirThreshold,
    DatabaseSchema.colConfigUpdatedAtMs: config == null
        ? null
        : (updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
  });

  /// Updates the generic status placeholder (e.g. 'ok', 'sleeping', error text).
  Future<int> updateStatusLabel(String id, String? statusLabel) =>
      _updateFields(id, {DatabaseSchema.colStatusLabel: statusLabel});

  /// Updates saved GPS coordinates for future macro-navigation.
  Future<int> updateLocation(String id, CameraLocation? location) =>
      _updateFields(id, {
        DatabaseSchema.colLatitude: location?.latitude,
        DatabaseSchema.colLongitude: location?.longitude,
        DatabaseSchema.colLocationUpdatedAtMs: location == null
            ? null
            : (location.updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
      });

  Future<int> updateNotes(String id, String? notes) =>
      _updateFields(id, {DatabaseSchema.colNotes: notes});

  /// Replaces the flexible JSON metadata map for ad-hoc future fields.
  Future<int> updateExtra(String id, Map<String, Object?> extra) =>
      _updateFields(id, {
        DatabaseSchema.colExtraJson: extra.isEmpty ? null : jsonEncode(extra),
      });

  Future<int> delete(String id) => _db.delete(
    DatabaseSchema.camerasTable,
    where: '${DatabaseSchema.colId} = ?',
    whereArgs: [id],
  );

  Future<int> clear() => _db.delete(DatabaseSchema.camerasTable);

  Future<void> _upsertRecord(
    DatabaseExecutor txn,
    CameraRecord record,
    DateTime now,
  ) {
    final map = record.copyWith(updatedAt: now).toMap();
    return _updateOrInsert(
      txn,
      id: record.id,
      bleMac: record.bleMac,
      // Keep the original creation time of an existing camera.
      updateValues: Map.of(map)..remove(DatabaseSchema.colCreatedAtMs),
      insertValues: map,
    );
  }

  /// UPDATE the row with [id]; if there is none, INSERT. Plain INSERT/UPDATE
  /// fail on a UNIQUE conflict instead of deleting the other row like
  /// `REPLACE` does. (Not `INSERT … ON CONFLICT DO UPDATE`: older Android
  /// versions ship a SQLite that doesn't support it.)
  ///
  /// Run inside a transaction so no other write can slip in between.
  Future<void> _updateOrInsert(
    DatabaseExecutor txn, {
    required String id,
    required String bleMac,
    required Map<String, Object?> updateValues,
    required Map<String, Object?> insertValues,
  }) async {
    try {
      final updated = await txn.update(
        DatabaseSchema.camerasTable,
        updateValues,
        where: '${DatabaseSchema.colId} = ?',
        whereArgs: [id],
      );
      if (updated == 0) {
        await txn.insert(DatabaseSchema.camerasTable, insertValues);
      }
    } on DatabaseException catch (e) {
      // SQLite reports the column as "cameras.ble_mac".
      if (e.isUniqueConstraintError(
        '${DatabaseSchema.camerasTable}.${DatabaseSchema.colBleMac}',
      )) {
        throw DuplicateBleMacException(CameraRecord.normalizeBleMac(bleMac));
      }
      rethrow;
    }
  }

  static Map<String, Object?> _statusColumns(DeviceStatus? status) => {
    DatabaseSchema.colBatteryPercent: status?.batteryPercent,
    DatabaseSchema.colSdFreeGb: status?.sdFreeGb,
    DatabaseSchema.colIsOnline: status == null
        ? null
        : (status.isOnline ? 1 : 0),
    DatabaseSchema.colLastSeenMs: status?.lastSeen?.millisecondsSinceEpoch,
  };

  Future<int> _updateFields(String id, Map<String, Object?> values) {
    final payload = <String, Object?>{
      ...values,
      DatabaseSchema.colUpdatedAtMs: DateTime.now().millisecondsSinceEpoch,
    };
    return _db.update(
      DatabaseSchema.camerasTable,
      payload,
      where: '${DatabaseSchema.colId} = ?',
      whereArgs: [id],
    );
  }
}
