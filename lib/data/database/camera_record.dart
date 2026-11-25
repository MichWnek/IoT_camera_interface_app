import 'dart:convert';

import 'package:camera_trap_app/data/database/database_schema.dart';
import 'package:camera_trap_app/data/models/camera_config.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';
import 'package:camera_trap_app/data/models/device_status.dart';
import 'package:flutter/foundation.dart';

/// Optional GPS coordinates stored for future macro-navigation features.
class CameraLocation {
  const CameraLocation({
    required this.latitude,
    required this.longitude,
    this.updatedAt,
  }) : assert(
         latitude >= -90 && latitude <= 90,
         'latitude must be between -90 and 90',
       ),
       assert(
         longitude >= -180 && longitude <= 180,
         'longitude must be between -180 and 180',
       );

  final double latitude;
  final double longitude;
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      other is CameraLocation &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(latitude, longitude, updatedAt);

  CameraLocation copyWith({
    double? latitude,
    double? longitude,
    DateTime? updatedAt,
  }) => CameraLocation(
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Persisted representation of a camera trap in SQLite.
///
/// Mirrors the existing domain models ([CameraTrap], [DeviceStatus],
/// [CameraConfig]) without modifying them, and adds nullable placeholders for
/// future features such as GPS location, generic status labels, notes, and
/// arbitrary JSON metadata ([extra]).
class CameraRecord {
  CameraRecord({
    required this.id,
    required this.name,
    required this.bleMac,
    this.status,
    this.lastConfig,
    this.configUpdatedAt,
    this.statusLabel,
    this.location,
    this.notes,
    Map<String, Object?>? extra,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : extra = Map.unmodifiable(extra ?? const {}),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Builds a database record from an existing [CameraTrap] model.
  factory CameraRecord.fromCameraTrap(
    CameraTrap trap, {
    CameraConfig? lastConfig,
    DateTime? configUpdatedAt,
    String? statusLabel,
    CameraLocation? location,
    String? notes,
    Map<String, Object?>? extra,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CameraRecord(
    id: trap.id,
    name: trap.name,
    bleMac: trap.bleMac,
    status: trap.status,
    lastConfig: lastConfig,
    configUpdatedAt: configUpdatedAt,
    statusLabel: statusLabel,
    location: location,
    notes: notes,
    extra: extra,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  final String id;
  final String name;
  final String bleMac;

  /// Last known battery, SD card space, online flag, and timestamp.
  final DeviceStatus? status;

  /// Last known camera configuration sent to or read from the device.
  final CameraConfig? lastConfig;
  final DateTime? configUpdatedAt;

  /// Generic status placeholder (e.g. 'ok', 'sleeping', 'error', etc.).
  final String? statusLabel;

  /// Optional saved GPS coordinates for future macro-navigation.
  final CameraLocation? location;

  /// Optional human-readable field notes.
  final String? notes;

  /// Flexible key-value JSON map for experimenting with extra attributes
  /// before promoting them to dedicated SQLite columns.
  final Map<String, Object?> extra;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Converts this persisted record back into the UI/domain [CameraTrap].
  CameraTrap toCameraTrap() =>
      CameraTrap(id: id, name: name, bleMac: bleMac, status: status);

  Map<String, Object?> toMap() => {
    DatabaseSchema.colId: id,
    DatabaseSchema.colName: name,
    DatabaseSchema.colBleMac: bleMac,
    DatabaseSchema.colBatteryPercent: status?.batteryPercent,
    DatabaseSchema.colSdFreeGb: status?.sdFreeGb,
    DatabaseSchema.colIsOnline: status == null
        ? null
        : (status!.isOnline ? 1 : 0),
    DatabaseSchema.colLastSeenMs: status?.lastSeen?.millisecondsSinceEpoch,
    DatabaseSchema.colAiThreshold: lastConfig?.aiThreshold,
    DatabaseSchema.colPirThreshold: lastConfig?.pirThreshold,
    DatabaseSchema.colConfigUpdatedAtMs:
        configUpdatedAt?.millisecondsSinceEpoch,
    DatabaseSchema.colStatusLabel: statusLabel,
    DatabaseSchema.colLatitude: location?.latitude,
    DatabaseSchema.colLongitude: location?.longitude,
    DatabaseSchema.colLocationUpdatedAtMs:
        location?.updatedAt?.millisecondsSinceEpoch,
    DatabaseSchema.colNotes: notes,
    DatabaseSchema.colExtraJson: extra.isEmpty ? null : jsonEncode(extra),
    DatabaseSchema.colCreatedAtMs: createdAt.millisecondsSinceEpoch,
    DatabaseSchema.colUpdatedAtMs: updatedAt.millisecondsSinceEpoch,
  };

  factory CameraRecord.fromMap(Map<String, Object?> map) {
    final battery = map[DatabaseSchema.colBatteryPercent] as int?;
    final sdFree = (map[DatabaseSchema.colSdFreeGb] as num?)?.toDouble();
    final isOnlineInt = map[DatabaseSchema.colIsOnline] as int?;
    final lastSeenMs = map[DatabaseSchema.colLastSeenMs] as int?;

    final DeviceStatus? status = battery != null && sdFree != null
        ? DeviceStatus(
            batteryPercent: battery,
            sdFreeGb: sdFree,
            isOnline: isOnlineInt == 1,
            lastSeen: lastSeenMs != null
                ? DateTime.fromMillisecondsSinceEpoch(lastSeenMs)
                : null,
          )
        : null;

    final ai = (map[DatabaseSchema.colAiThreshold] as num?)?.toDouble();
    final pir = (map[DatabaseSchema.colPirThreshold] as num?)?.toDouble();
    final CameraConfig? lastConfig = ai != null && pir != null
        ? CameraConfig(aiThreshold: ai, pirThreshold: pir)
        : null;

    final lat = (map[DatabaseSchema.colLatitude] as num?)?.toDouble();
    final lng = (map[DatabaseSchema.colLongitude] as num?)?.toDouble();
    final locUpdatedMs = map[DatabaseSchema.colLocationUpdatedAtMs] as int?;
    final CameraLocation? location = lat != null && lng != null
        ? CameraLocation(
            latitude: lat,
            longitude: lng,
            updatedAt: locUpdatedMs != null
                ? DateTime.fromMillisecondsSinceEpoch(locUpdatedMs)
                : null,
          )
        : null;

    final extraRaw = map[DatabaseSchema.colExtraJson] as String?;
    final Map<String, Object?> extra = extraRaw != null && extraRaw.isNotEmpty
        ? Map<String, Object?>.from(jsonDecode(extraRaw) as Map)
        : const {};

    final configUpdatedMs = map[DatabaseSchema.colConfigUpdatedAtMs] as int?;

    return CameraRecord(
      id: map[DatabaseSchema.colId] as String,
      name: map[DatabaseSchema.colName] as String,
      bleMac: map[DatabaseSchema.colBleMac] as String,
      status: status,
      lastConfig: lastConfig,
      configUpdatedAt: configUpdatedMs != null
          ? DateTime.fromMillisecondsSinceEpoch(configUpdatedMs)
          : null,
      statusLabel: map[DatabaseSchema.colStatusLabel] as String?,
      location: location,
      notes: map[DatabaseSchema.colNotes] as String?,
      extra: extra,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map[DatabaseSchema.colCreatedAtMs] as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map[DatabaseSchema.colUpdatedAtMs] as int,
      ),
    );
  }

  CameraRecord copyWith({
    String? id,
    String? name,
    String? bleMac,
    DeviceStatus? status,
    bool clearStatus = false,
    CameraConfig? lastConfig,
    bool clearLastConfig = false,
    DateTime? configUpdatedAt,
    String? statusLabel,
    bool clearStatusLabel = false,
    CameraLocation? location,
    bool clearLocation = false,
    String? notes,
    bool clearNotes = false,
    Map<String, Object?>? extra,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CameraRecord(
    id: id ?? this.id,
    name: name ?? this.name,
    bleMac: bleMac ?? this.bleMac,
    status: clearStatus ? null : (status ?? this.status),
    lastConfig: clearLastConfig ? null : (lastConfig ?? this.lastConfig),
    configUpdatedAt: clearLastConfig
        ? null
        : (configUpdatedAt ?? this.configUpdatedAt),
    statusLabel: clearStatusLabel ? null : (statusLabel ?? this.statusLabel),
    location: clearLocation ? null : (location ?? this.location),
    notes: clearNotes ? null : (notes ?? this.notes),
    extra: extra ?? this.extra,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is CameraRecord &&
      other.id == id &&
      other.name == name &&
      other.bleMac == bleMac &&
      other.status == status &&
      other.lastConfig == lastConfig &&
      other.configUpdatedAt == configUpdatedAt &&
      other.statusLabel == statusLabel &&
      other.location == location &&
      other.notes == notes &&
      mapEquals(other.extra, extra) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    bleMac,
    status,
    lastConfig,
    configUpdatedAt,
    statusLabel,
    location,
    notes,
    createdAt,
    updatedAt,
  );
}
