import 'dart:async';

import 'package:camera_trap_app/data/ble/ble_adapter.dart';
import 'package:camera_trap_app/data/ble/ble_types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// [BleAdapter] backed by the flutter_blue_plus plugin.
///
/// flutter_blue_plus 2.x is free for personal, nonprofit and educational
/// use only; for-profit use needs a commercial licence. See its LICENSE.
class FlutterBluePlusAdapter implements BleAdapter {
  FlutterBluePlusAdapter({this.license = License.nonprofit});

  final License license;

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  /// What the system asks the user for. On Android 11 and older these report
  /// as granted; the location permission those versions need for scanning
  /// is requested by flutter_blue_plus itself when a scan starts.
  List<ph.Permission> get _permissions => _isIos
      ? [ph.Permission.bluetooth]
      : [ph.Permission.bluetoothScan, ph.Permission.bluetoothConnect];

  /// Null when all permissions are granted.
  Future<BleAvailability?> _missingPermission() async {
    final statuses = [
      for (final permission in _permissions) await permission.status,
    ];
    if (statuses.every((s) => s.isGranted || s.isLimited)) return null;
    if (statuses.any((s) => s.isPermanentlyDenied || s.isRestricted)) {
      return BleAvailability.permissionPermanentlyDenied;
    }
    return BleAvailability.permissionRequired;
  }

  static BleAvailability _fromAdapterState(BluetoothAdapterState state) =>
      switch (state) {
        BluetoothAdapterState.on => BleAvailability.ready,
        BluetoothAdapterState.off ||
        BluetoothAdapterState.turningOff => BleAvailability.off,
        BluetoothAdapterState.unauthorized =>
          BleAvailability.permissionRequired,
        BluetoothAdapterState.unavailable => BleAvailability.unsupported,
        BluetoothAdapterState.turningOn ||
        BluetoothAdapterState.unknown => BleAvailability.checking,
      };

  @override
  Stream<BleAvailability> watchAvailability() async* {
    yield BleAvailability.checking;
    if (!await FlutterBluePlus.isSupported) {
      yield BleAvailability.unsupported;
      return;
    }
    final missing = await _missingPermission();
    if (missing != null) {
      yield missing;
      return;
    }
    yield* FlutterBluePlus.adapterState.map(_fromAdapterState).distinct();
  }

  @override
  Future<void> requestPermissions() => _permissions.request();

  @override
  bool get canTurnOn => !_isIos;

  @override
  Future<void> turnOn() => FlutterBluePlus.turnOn();

  @override
  Future<void> openSettings() => ph.openAppSettings();

  @override
  Stream<List<BleScanResult>> scan({
    Duration timeout = const Duration(seconds: 15),
  }) {
    StreamSubscription<List<ScanResult>>? results;
    StreamSubscription<bool>? scanEnded;
    late final StreamController<List<BleScanResult>> controller;

    controller = StreamController(
      onListen: () async {
        results = FlutterBluePlus.onScanResults.listen(
          (found) => controller.add([for (final r in found) _toScanResult(r)]),
          onError: controller.addError,
        );
        try {
          await FlutterBluePlus.startScan(
            timeout: timeout,
            // Keep re-reporting devices so signal strength stays current,
            // and drop devices that stop advertising.
            continuousUpdates: true,
            removeIfGone: const Duration(seconds: 10),
            // Only Android 11 and older need Location switched on; on newer
            // phones this check would block scanning for no reason.
            androidCheckLocationServices: false,
          );
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
          await controller.close();
          return;
        }
        scanEnded = FlutterBluePlus.isScanning
            .where((scanning) => !scanning)
            .listen((_) => controller.close());
      },
      onCancel: () async {
        await results?.cancel();
        await scanEnded?.cancel();
        if (FlutterBluePlus.isScanningNow) {
          await FlutterBluePlus.stopScan();
        }
      },
    );
    return controller.stream;
  }

  static BleScanResult _toScanResult(ScanResult result) => BleScanResult(
    id: result.device.remoteId.str,
    name: result.advertisementData.advName.isNotEmpty
        ? result.advertisementData.advName
        : result.device.platformName,
    rssi: result.rssi,
  );

  @override
  Future<void> connect(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
  }) =>
      BluetoothDevice.fromId(deviceId)
          .connect(license: license, timeout: timeout);

  @override
  Future<void> disconnect(String deviceId) =>
      BluetoothDevice.fromId(deviceId).disconnect();

  @override
  Stream<BleConnectionState> watchConnection(String deviceId) =>
      BluetoothDevice.fromId(deviceId).connectionState.map(
        (state) => state == BluetoothConnectionState.connected
            ? BleConnectionState.connected
            : BleConnectionState.disconnected,
      );

  @override
  Future<List<BleServiceInfo>> discoverServices(String deviceId) async {
    final services = await BluetoothDevice.fromId(deviceId).discoverServices();
    return [
      for (final service in services)
        BleServiceInfo(
          uuid: service.uuid.str,
          characteristics: [
            for (final c in service.characteristics)
              BleCharacteristicInfo(
                uuid: c.uuid.str,
                canRead: c.properties.read,
                canWrite:
                    c.properties.write || c.properties.writeWithoutResponse,
                canNotify: c.properties.notify || c.properties.indicate,
              ),
          ],
        ),
    ];
  }

  Future<BluetoothCharacteristic> _characteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
  ) async {
    final device = BluetoothDevice.fromId(deviceId);
    var services = device.servicesList;
    if (services.isEmpty) {
      services = await device.discoverServices();
    }
    final service = services
        .where((s) => s.uuid == Guid(serviceUuid))
        .firstOrNull;
    final characteristic = service?.characteristics
        .where((c) => c.uuid == Guid(characteristicUuid))
        .firstOrNull;
    if (characteristic == null) {
      throw StateError(
        'Characteristic $characteristicUuid in service $serviceUuid '
        'not found on $deviceId',
      );
    }
    return characteristic;
  }

  @override
  Future<List<int>> read(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    final characteristic = await _characteristic(
      deviceId,
      serviceUuid,
      characteristicUuid,
    );
    return characteristic.read();
  }

  @override
  Future<void> write(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    bool withoutResponse = false,
  }) async {
    final characteristic = await _characteristic(
      deviceId,
      serviceUuid,
      characteristicUuid,
    );
    await characteristic.write(value, withoutResponse: withoutResponse);
  }

  @override
  Stream<List<int>> subscribe(
    String deviceId, {
    required String serviceUuid,
    required String characteristicUuid,
  }) {
    BluetoothCharacteristic? characteristic;
    StreamSubscription<List<int>>? values;
    late final StreamController<List<int>> controller;

    controller = StreamController(
      onListen: () async {
        try {
          characteristic = await _characteristic(
            deviceId,
            serviceUuid,
            characteristicUuid,
          );
          values = characteristic!.onValueReceived.listen(
            controller.add,
            onError: controller.addError,
          );
          await characteristic!.setNotifyValue(true);
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
        }
      },
      onCancel: () async {
        await values?.cancel();
        final c = characteristic;
        if (c != null && BluetoothDevice.fromId(deviceId).isConnected) {
          try {
            await c.setNotifyValue(false);
          } catch (_) {
            // The device may have gone away meanwhile; nothing to undo.
          }
        }
      },
    );
    return controller.stream;
  }
}
