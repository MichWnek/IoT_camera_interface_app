import 'package:bloc_test/bloc_test.dart';
import 'package:camera_trap_app/data/ble/ble_types.dart';
import 'package:camera_trap_app/state/scan_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_ble_adapter.dart';

void main() {
  const far = BleScanResult(id: 'A', name: 'CamTrap far', rssi: -90);
  const near = BleScanResult(id: 'B', name: 'CamTrap near', rssi: -40);
  const unnamed = BleScanResult(id: 'C', name: '', rssi: -50);

  late FakeBleAdapter adapter;

  setUp(() => adapter = FakeBleAdapter());

  blocTest<ScanCubit, ScanState>(
    'start scans and lists results strongest first',
    build: () => ScanCubit(adapter),
    act: (cubit) async {
      await cubit.start();
      adapter.scanController.add([far, near]);
    },
    expect: () => [
      const ScanState(isScanning: true),
      const ScanState(isScanning: true, results: [near, far]),
    ],
  );

  blocTest<ScanCubit, ScanState>(
    'the scan ending stops the scanning state but keeps the results',
    build: () => ScanCubit(adapter),
    act: (cubit) async {
      await cubit.start();
      adapter.scanController.add([near]);
      await adapter.finishScan();
    },
    skip: 2,
    expect: () => [
      const ScanState(results: [near]),
    ],
  );

  blocTest<ScanCubit, ScanState>(
    'a failed scan shows an error',
    build: () => ScanCubit(adapter),
    act: (cubit) async {
      await cubit.start();
      adapter.scanController.addError(Exception('no permission'));
    },
    skip: 1,
    expect: () => [
      const ScanState(error: 'Scan failed. Check that Bluetooth is on.'),
    ],
  );

  test('stop cancels the scan', () async {
    final cubit = ScanCubit(adapter);
    await cubit.start();

    await cubit.stop();

    expect(adapter.scanCancelled, isTrue);
    expect(cubit.state.isScanning, isFalse);
    await cubit.close();
  });

  test('closing the cubit cancels a running scan', () async {
    final cubit = ScanCubit(adapter);
    await cubit.start();

    await cubit.close();

    expect(adapter.scanCancelled, isTrue);
  });

  test('unnamed devices are hidden unless asked for', () {
    const state = ScanState(results: [near, unnamed, far]);

    expect(state.visibleResults, [near, far]);
    expect(state.copyWith(showUnnamed: true).visibleResults, [
      near,
      unnamed,
      far,
    ]);
  });
}
