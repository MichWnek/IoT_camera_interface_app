import 'dart:async';

import 'package:camera_trap_app/data/ble/ble_adapter.dart';
import 'package:camera_trap_app/data/ble/ble_types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@immutable
class ScanState {
  const ScanState({
    this.isScanning = false,
    this.results = const [],
    this.showUnnamed = false,
    this.error,
  });

  final bool isScanning;

  /// Everything found, strongest signal first.
  final List<BleScanResult> results;

  /// Devices without a name are usually phones, headphones and the like.
  final bool showUnnamed;

  final String? error;

  List<BleScanResult> get visibleResults => showUnnamed
      ? results
      : [
          for (final r in results)
            if (r.hasName) r,
        ];

  ScanState copyWith({
    bool? isScanning,
    List<BleScanResult>? results,
    bool? showUnnamed,
    String? error,
  }) => ScanState(
    isScanning: isScanning ?? this.isScanning,
    results: results ?? this.results,
    showUnnamed: showUnnamed ?? this.showUnnamed,
    error: error ?? this.error,
  );

  @override
  bool operator ==(Object other) =>
      other is ScanState &&
      other.isScanning == isScanning &&
      listEquals(other.results, results) &&
      other.showUnnamed == showUnnamed &&
      other.error == error;

  @override
  int get hashCode =>
      Object.hash(isScanning, Object.hashAll(results), showUnnamed, error);
}

class ScanCubit extends Cubit<ScanState> {
  ScanCubit(this._adapter, {this.scanDuration = const Duration(seconds: 15)})
    : super(const ScanState());

  final BleAdapter _adapter;
  final Duration scanDuration;
  StreamSubscription<List<BleScanResult>>? _scan;

  Future<void> start() async {
    await _scan?.cancel();
    emit(ScanState(isScanning: true, showUnnamed: state.showUnnamed));

    _scan = _adapter
        .scan(timeout: scanDuration)
        .listen(
          (results) => emit(
            state.copyWith(
              results: [...results]..sort((a, b) => b.rssi.compareTo(a.rssi)),
            ),
          ),
          onError: (Object _) => emit(
            ScanState(
              results: state.results,
              showUnnamed: state.showUnnamed,
              error: 'Scan failed. Check that Bluetooth is on.',
            ),
          ),
          onDone: () {
            if (!isClosed) emit(state.copyWith(isScanning: false));
          },
        );
  }

  /// Shows the scan as stopped straight away, then waits for the plugin.
  Future<void> stop() async {
    final scan = _scan;
    _scan = null;
    if (!isClosed) emit(state.copyWith(isScanning: false));
    await scan?.cancel();
  }

  void setShowUnnamed(bool show) => emit(state.copyWith(showUnnamed: show));

  @override
  Future<void> close() async {
    await _scan?.cancel();
    return super.close();
  }
}
