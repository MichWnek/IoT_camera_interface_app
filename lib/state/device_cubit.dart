import 'dart:async';

import 'package:camera_trap_app/data/ble/ble_adapter.dart';
import 'package:camera_trap_app/data/ble/ble_types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum DevicePhase {
  disconnected,
  connecting,
  discovering,
  connected,
  disconnecting,
}

@immutable
class DeviceState {
  const DeviceState({
    this.phase = DevicePhase.disconnected,
    this.services = const [],
    this.error,
  });

  final DevicePhase phase;
  final List<BleServiceInfo> services;
  final String? error;

  bool get isBusy =>
      phase == DevicePhase.connecting ||
      phase == DevicePhase.discovering ||
      phase == DevicePhase.disconnecting;

  @override
  bool operator ==(Object other) =>
      other is DeviceState &&
      other.phase == phase &&
      listEquals(other.services, services) &&
      other.error == error;

  @override
  int get hashCode => Object.hash(phase, Object.hashAll(services), error);
}

/// Connection to one device, for as long as its screen is open.
class DeviceCubit extends Cubit<DeviceState> {
  DeviceCubit(
    this._adapter,
    this.deviceId, {
    this.connectTimeout = const Duration(seconds: 15),
  }) : super(const DeviceState()) {
    _connection = _adapter.watchConnection(deviceId).listen(_onConnection);
  }

  final BleAdapter _adapter;
  final String deviceId;
  final Duration connectTimeout;
  late final StreamSubscription<BleConnectionState> _connection;
  bool _closing = false;

  void _onConnection(BleConnectionState connection) {
    if (_closing) return; // our own disconnect, not a lost connection
    final wasLinked =
        state.phase == DevicePhase.connected ||
        state.phase == DevicePhase.discovering;
    if (connection == BleConnectionState.disconnected && wasLinked) {
      emit(const DeviceState(error: 'Connection lost'));
    }
  }

  Future<void> connect() async {
    emit(const DeviceState(phase: DevicePhase.connecting));
    try {
      await _adapter.connect(deviceId, timeout: connectTimeout);
      if (isClosed) return;
      emit(const DeviceState(phase: DevicePhase.discovering));
      final services = await _adapter.discoverServices(deviceId);
      if (isClosed) return;
      emit(DeviceState(phase: DevicePhase.connected, services: services));
    } catch (_) {
      if (isClosed) return;
      emit(const DeviceState(error: 'Could not connect to the device'));
    }
  }

  Future<void> disconnect() async {
    emit(const DeviceState(phase: DevicePhase.disconnecting));
    try {
      await _adapter.disconnect(deviceId);
    } finally {
      if (!isClosed) emit(const DeviceState());
    }
  }

  /// Reads a characteristic and returns its value as hex, e.g. `0x01 a4`.
  Future<String> readHex(String serviceUuid, String characteristicUuid) async {
    final value = await _adapter.read(
      deviceId,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
    );
    if (value.isEmpty) return '(empty)';
    return '0x${value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}';
  }

  /// Leaving the screen ends the connection. Disconnects first, so the
  /// device is released as soon as possible.
  @override
  Future<void> close() async {
    _closing = true;
    if (state.phase != DevicePhase.disconnected) {
      try {
        await _adapter.disconnect(deviceId);
      } catch (_) {
        // Already gone; nothing to clean up.
      }
    }
    await _connection.cancel();
    return super.close();
  }
}
