import 'package:bloc_test/bloc_test.dart';
import 'package:camera_trap_app/data/ble/ble_types.dart';
import 'package:camera_trap_app/state/device_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_ble_adapter.dart';

void main() {
  const services = [
    BleServiceInfo(
      uuid: '180f',
      characteristics: [BleCharacteristicInfo(uuid: '2a19', canRead: true)],
    ),
  ];

  late FakeBleAdapter adapter;

  setUp(() => adapter = FakeBleAdapter(services: services));

  blocTest<DeviceCubit, DeviceState>(
    'connect goes through connecting and discovering to connected',
    build: () => DeviceCubit(adapter, 'dev'),
    act: (cubit) => cubit.connect(),
    expect: () => [
      const DeviceState(phase: DevicePhase.connecting),
      const DeviceState(phase: DevicePhase.discovering),
      const DeviceState(phase: DevicePhase.connected, services: services),
    ],
  );

  blocTest<DeviceCubit, DeviceState>(
    'a failed connection ends disconnected with an error',
    setUp: () => adapter = FakeBleAdapter(connectFails: true),
    build: () => DeviceCubit(adapter, 'dev'),
    act: (cubit) => cubit.connect(),
    expect: () => [
      const DeviceState(phase: DevicePhase.connecting),
      const DeviceState(error: 'Could not connect to the device'),
    ],
  );

  blocTest<DeviceCubit, DeviceState>(
    'losing the connection is reported',
    build: () => DeviceCubit(adapter, 'dev'),
    act: (cubit) async {
      await cubit.connect();
      adapter.loseConnection();
    },
    skip: 3,
    expect: () => [const DeviceState(error: 'Connection lost')],
  );

  blocTest<DeviceCubit, DeviceState>(
    'disconnecting on purpose is not reported as lost',
    build: () => DeviceCubit(adapter, 'dev'),
    act: (cubit) async {
      await cubit.connect();
      await cubit.disconnect();
    },
    skip: 3,
    expect: () => [
      const DeviceState(phase: DevicePhase.disconnecting),
      const DeviceState(),
    ],
  );

  test('closing the cubit disconnects', () async {
    final cubit = DeviceCubit(adapter, 'dev');
    await cubit.connect();

    await cubit.close();

    expect(adapter.disconnectCalls, 1);
  });

  test('readHex formats the value as hex bytes', () async {
    adapter.readValues = {
      '2a19': [0x01, 0xa4],
    };
    final cubit = DeviceCubit(adapter, 'dev');

    expect(await cubit.readHex('180f', '2a19'), '0x01 a4');
    await cubit.close();
  });
}
