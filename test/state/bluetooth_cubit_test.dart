import 'package:bloc_test/bloc_test.dart';
import 'package:camera_trap_app/data/ble/ble_types.dart';
import 'package:camera_trap_app/state/bluetooth_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_ble_adapter.dart';

void main() {
  late FakeBleAdapter adapter;

  setUp(() => adapter = FakeBleAdapter(availability: BleAvailability.off));

  blocTest<BluetoothCubit, BleAvailability>(
    'reports the availability, then every change',
    build: () => BluetoothCubit(adapter),
    act: (_) async {
      await Future<void>.delayed(Duration.zero);
      adapter.changeAvailability(BleAvailability.ready);
    },
    expect: () => [BleAvailability.off, BleAvailability.ready],
  );

  blocTest<BluetoothCubit, BleAvailability>(
    'after asking for permission, checks availability again',
    setUp: () => adapter = FakeBleAdapter(
      availability: BleAvailability.permissionRequired,
    ),
    build: () => BluetoothCubit(adapter),
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero);
      adapter.availability = BleAvailability.ready; // the user allowed it
      await cubit.requestPermissions();
    },
    expect: () => [BleAvailability.permissionRequired, BleAvailability.ready],
    verify: (_) => expect(adapter.requestPermissionsCalls, 1),
  );

  blocTest<BluetoothCubit, BleAvailability>(
    'recheck picks up a change made in the system settings',
    setUp: () => adapter = FakeBleAdapter(
      availability: BleAvailability.permissionPermanentlyDenied,
    ),
    build: () => BluetoothCubit(adapter),
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero);
      adapter.availability = BleAvailability.ready;
      cubit.recheck();
    },
    expect: () => [
      BleAvailability.permissionPermanentlyDenied,
      BleAvailability.ready,
    ],
  );

  test('turnOn and openSettings are passed to the adapter', () async {
    final cubit = BluetoothCubit(adapter);

    await cubit.turnOn();
    await cubit.openSettings();

    expect(adapter.turnOnCalls, 1);
    expect(adapter.openSettingsCalls, 1);
    await cubit.close();
  });
}
