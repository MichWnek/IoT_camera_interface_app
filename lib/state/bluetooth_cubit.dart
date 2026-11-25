import 'dart:async';

import 'package:camera_trap_app/data/ble/ble_adapter.dart';
import 'package:camera_trap_app/data/ble/ble_types.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// App-wide Bluetooth availability: supported, permitted, switched on.
class BluetoothCubit extends Cubit<BleAvailability> {
  BluetoothCubit(this._adapter) : super(BleAvailability.checking) {
    _watch();
  }

  final BleAdapter _adapter;
  StreamSubscription<BleAvailability>? _availability;

  bool get canTurnOn => _adapter.canTurnOn;

  void _watch() {
    _availability?.cancel();
    _availability = _adapter.watchAvailability().listen((availability) {
      if (!isClosed) emit(availability);
    });
  }

  /// Checks again, e.g. when the user comes back from the system settings.
  void recheck() => _watch();

  Future<void> requestPermissions() async {
    await _adapter.requestPermissions();
    _watch();
  }

  /// The new state arrives through [BleAdapter.watchAvailability].
  Future<void> turnOn() async {
    try {
      await _adapter.turnOn();
    } catch (_) {
      // The user declined the system prompt; the screen still offers it.
    }
  }

  Future<void> openSettings() => _adapter.openSettings();

  @override
  Future<void> close() async {
    await _availability?.cancel();
    return super.close();
  }
}
