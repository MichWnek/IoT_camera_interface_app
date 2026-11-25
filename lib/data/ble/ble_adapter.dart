import 'package:camera_trap_app/data/ble/ble_types.dart';

/// Protocol-independent Bluetooth LE access.
///
/// Screens and cubits only use this interface and the types in
/// `ble_types.dart`, never the BLE plugin directly, so the plugin can be
/// replaced and everything can be tested with a fake. The camera protocol
/// (UUIDs, byte formats) will be built on top of [read], [write] and
/// [subscribe] once the hardware team has defined it.
abstract interface class BleAdapter {
  /// Current availability, then every change (e.g. Bluetooth switched off).
  /// Listen again after asking for permission to re-check it.
  Stream<BleAvailability> watchAvailability();

  /// Shows the system permission prompts, if the system still allows it.
  Future<void> requestPermissions();

  /// Whether [turnOn] works on this platform (Android yes, iOS no).
  bool get canTurnOn;

  /// Asks the system to switch Bluetooth on.
  Future<void> turnOn();

  /// Opens this app's page in the system settings.
  Future<void> openSettings();

  /// Scans for [timeout]. Each event is the full list found so far, with
  /// updated signal strength. Completes when the scan ends; cancelling the
  /// subscription stops the scan early.
  Stream<List<BleScanResult>> scan({
    Duration timeout = const Duration(seconds: 15),
  });

  Future<void> connect(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
  });

  Future<void> disconnect(String deviceId);

  /// Current connection state, then every change.
  Stream<BleConnectionState> watchConnection(String deviceId);

  /// Lists the device's services. Must be connected.
  Future<List<BleServiceInfo>> discoverServices(String deviceId);

  Future<List<int>> read(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
  });

  Future<void> write(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    bool withoutResponse = false,
  });

  /// Values the device notifies, for as long as the stream is listened to.
  Stream<List<int>> subscribe(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
  });
}
