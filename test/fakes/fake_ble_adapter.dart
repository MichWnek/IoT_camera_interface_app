import 'dart:async';

import 'package:camera_trap_app/data/ble/ble_adapter.dart';
import 'package:camera_trap_app/data/ble/ble_types.dart';

/// A [BleAdapter] the test controls completely: it decides the availability,
/// pushes scan results and connection changes by hand, and records calls.
class FakeBleAdapter implements BleAdapter {
  FakeBleAdapter({
    this.availability = BleAvailability.ready,
    this.services = const [],
    this.connectFails = false,
    this.canTurnOn = true,
  });

  /// What [watchAvailability] reports next time it's listened to.
  BleAvailability availability;
  final List<BleServiceInfo> services;
  bool connectFails;
  Map<String, List<int>> readValues = {};

  @override
  final bool canTurnOn;

  final _availabilityChanges = StreamController<BleAvailability>.broadcast();
  final scanController = StreamController<List<BleScanResult>>.broadcast();
  final _connectionChanges = StreamController<BleConnectionState>.broadcast();

  int requestPermissionsCalls = 0;
  int turnOnCalls = 0;
  int openSettingsCalls = 0;
  int scanCalls = 0;
  int disconnectCalls = 0;
  bool scanCancelled = false;

  /// Simulates a change while the app is watching, e.g. Bluetooth turned off.
  void changeAvailability(BleAvailability value) {
    availability = value;
    _availabilityChanges.add(value);
  }

  /// Simulates the device dropping the connection.
  void loseConnection() =>
      _connectionChanges.add(BleConnectionState.disconnected);

  /// Forwards [source] through a single-subscription stream whose cancel
  /// completes immediately. Cancelling a broadcast subscription directly
  /// returns a future that only completes on the real event loop, so in a
  /// widget test's simulated time anything awaiting it would wait forever.
  Stream<T> _forward<T>(Stream<T> source, {void Function()? onCancel}) {
    StreamSubscription<T>? subscription;
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () => subscription = source.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      ),
      onCancel: () {
        onCancel?.call();
        subscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Stream<BleAvailability> watchAvailability() async* {
    yield availability;
    yield* _forward(_availabilityChanges.stream);
  }

  @override
  Future<void> requestPermissions() async {
    requestPermissionsCalls++;
  }

  @override
  Future<void> turnOn() async {
    turnOnCalls++;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCalls++;
  }

  @override
  Stream<List<BleScanResult>> scan({
    Duration timeout = const Duration(seconds: 15),
  }) {
    scanCalls++;
    scanCancelled = false;
    return _forward(
      scanController.stream,
      onCancel: () => scanCancelled = true,
    );
  }

  /// Ends the current scan, like a scan timeout.
  Future<void> finishScan() async {
    await scanController.close();
  }

  @override
  Future<void> connect(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (connectFails) throw Exception('connect failed');
    _connectionChanges.add(BleConnectionState.connected);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    disconnectCalls++;
    _connectionChanges.add(BleConnectionState.disconnected);
  }

  @override
  Stream<BleConnectionState> watchConnection(String deviceId) =>
      _forward(_connectionChanges.stream);

  @override
  Future<List<BleServiceInfo>> discoverServices(String deviceId) async =>
      services;

  @override
  Future<List<int>> read(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
  }) async => readValues[characteristicUuid] ?? const [];

  @override
  Future<void> write(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    bool withoutResponse = false,
  }) async {}

  @override
  Stream<List<int>> subscribe(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
  }) => const Stream.empty();
}
