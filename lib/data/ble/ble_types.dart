import 'package:flutter/foundation.dart';

/// Whether Bluetooth can be used right now, and if not, what the user can
/// do about it.
enum BleAvailability {
  checking,

  /// The phone has no Bluetooth LE.
  unsupported,

  /// The app hasn't been allowed to use Bluetooth yet; it can ask.
  permissionRequired,

  /// The user refused and the system won't ask again; only app settings help.
  permissionPermanentlyDenied,

  /// Bluetooth is switched off.
  off,

  ready,
}

enum BleConnectionState { disconnected, connected }

/// A device found while scanning.
@immutable
class BleScanResult {
  const BleScanResult({
    required this.id,
    required this.name,
    required this.rssi,
  });

  /// Platform identifier: the MAC address on Android, a UUID on iOS.
  final String id;

  /// Advertised name, or empty if the device doesn't send one.
  final String name;

  /// Signal strength in dBm; closer to 0 is stronger.
  final int rssi;

  bool get hasName => name.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is BleScanResult &&
      other.id == id &&
      other.name == name &&
      other.rssi == rssi;

  @override
  int get hashCode => Object.hash(id, name, rssi);
}

@immutable
class BleCharacteristicInfo {
  const BleCharacteristicInfo({
    required this.uuid,
    this.canRead = false,
    this.canWrite = false,
    this.canNotify = false,
  });

  final String uuid;
  final bool canRead;
  final bool canWrite;

  /// Supports notifications or indications.
  final bool canNotify;

  @override
  bool operator ==(Object other) =>
      other is BleCharacteristicInfo &&
      other.uuid == uuid &&
      other.canRead == canRead &&
      other.canWrite == canWrite &&
      other.canNotify == canNotify;

  @override
  int get hashCode => Object.hash(uuid, canRead, canWrite, canNotify);
}

@immutable
class BleServiceInfo {
  const BleServiceInfo({required this.uuid, required this.characteristics});

  final String uuid;
  final List<BleCharacteristicInfo> characteristics;

  @override
  bool operator ==(Object other) =>
      other is BleServiceInfo &&
      other.uuid == uuid &&
      listEquals(other.characteristics, characteristics);

  @override
  int get hashCode => Object.hash(uuid, Object.hashAll(characteristics));
}
