import 'dart:convert';

import 'package:camera_trap_app/data/database/app_database.dart';
import 'package:camera_trap_app/data/database/camera_record.dart';
import 'package:camera_trap_app/data/database/database_schema.dart';
import 'package:camera_trap_app/data/models/camera_config.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';
import 'package:camera_trap_app/data/models/device_status.dart';
import 'package:sqflite/sqflite.dart';

/// CRUD and targeted update operations for the `cameras` SQLite table.
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
      whereArgs: [bleMac],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CameraRecord.fromMap(rows.first);
  }

  /// Inserts a new camera or replaces an existing one with the same [id].
  Future<void> upsert(CameraRecord record) async {
    final now = DateTime.now();
    final map = record.copyWith(updatedAt: now).toMap();
    await _db.insert(
      DatabaseSchema.camerasTable,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserts multiple cameras in a single transaction.
  Future<void> upsertAll(List<CameraRecord> records) async {
    await _db.transaction((txn) async {
      final now = DateTime.now();
      for (final record in records) {
        await txn.insert(
          DatabaseSchema.camerasTable,
          record.copyWith(updatedAt: now).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<int> updateName(String id, String name) => _updateFields(id, {
    DatabaseSchema.colName: name,
  });

  /// Updates the last known [DeviceStatus] (battery, SD space, online state).
  /// Pass `null` to clear the stored status.
  Future<int> updateStatus(String id, DeviceStatus? status) =>
      _updateFields(id, {
        DatabaseSchema.colBatteryPercent: status?.batteryPercent,
        DatabaseSchema.colSdFreeGb: status?.sdFreeGb,
        DatabaseSchema.colIsOnline: status == null
            ? null
            : (status.isOnline ? 1 : 0),
        DatabaseSchema.colLastSeenMs: status?.lastSeen?.millisecondsSinceEpoch,
      });

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
