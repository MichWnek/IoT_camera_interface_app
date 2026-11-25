import 'package:camera_trap_app/data/ble/ble_adapter.dart';
import 'package:camera_trap_app/data/ble/ble_types.dart';
import 'package:camera_trap_app/features/nearby/view/device_screen.dart';
import 'package:camera_trap_app/features/nearby/view/nearby_devices_screen.dart';
import 'package:camera_trap_app/state/bluetooth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_ble_adapter.dart';

Future<void> pumpNearby(WidgetTester tester, FakeBleAdapter adapter) async {
  await tester.pumpWidget(
    RepositoryProvider<BleAdapter>.value(
      value: adapter,
      child: BlocProvider(
        create: (_) => BluetoothCubit(adapter),
        child: const MaterialApp(home: NearbyDevicesScreen()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  const camTrap = BleScanResult(id: 'AA:BB', name: 'CamTrap-01', rssi: -55);
  const phone = BleScanResult(id: 'CC:DD', name: '', rssi: -40);

  testWidgets('Asks for permission when it is missing', (tester) async {
    final adapter = FakeBleAdapter(
      availability: BleAvailability.permissionRequired,
    );
    await pumpNearby(tester, adapter);

    await tester.tap(find.text('Allow Bluetooth'));
    await tester.pump();

    expect(adapter.requestPermissionsCalls, 1);
  });

  testWidgets('Sends the user to settings when permission was refused', (
    tester,
  ) async {
    final adapter = FakeBleAdapter(
      availability: BleAvailability.permissionPermanentlyDenied,
    );
    await pumpNearby(tester, adapter);

    await tester.tap(find.text('Open settings'));
    await tester.pump();

    expect(adapter.openSettingsCalls, 1);
  });

  testWidgets('Offers to turn Bluetooth on when it is off', (tester) async {
    final adapter = FakeBleAdapter(availability: BleAvailability.off);
    await pumpNearby(tester, adapter);

    await tester.tap(find.text('Turn on Bluetooth'));
    await tester.pump();

    expect(adapter.turnOnCalls, 1);
  });

  testWidgets('Where Bluetooth cannot be turned on by the app, explains how', (
    tester,
  ) async {
    final adapter = FakeBleAdapter(
      availability: BleAvailability.off,
      canTurnOn: false,
    );
    await pumpNearby(tester, adapter);

    expect(find.text('Turn on Bluetooth'), findsNothing);
    expect(find.textContaining('Control Center'), findsOneWidget);
  });

  testWidgets('Scans automatically once ready and lists named devices', (
    tester,
  ) async {
    final adapter = FakeBleAdapter();
    await pumpNearby(tester, adapter);

    expect(adapter.scanCalls, 1);
    adapter.scanController.add([camTrap, phone]);
    await tester.pump();

    expect(find.text('CamTrap-01'), findsOneWidget);
    expect(find.text('-55 dBm'), findsOneWidget);
    expect(find.text('Unnamed device'), findsNothing);

    await tester.tap(find.text('Show unnamed'));
    await tester.pump();
    expect(find.text('Unnamed device'), findsOneWidget);
  });

  testWidgets('Starts scanning when Bluetooth is switched on', (tester) async {
    final adapter = FakeBleAdapter(availability: BleAvailability.off);
    await pumpNearby(tester, adapter);
    expect(adapter.scanCalls, 0);

    adapter.changeAvailability(BleAvailability.ready);
    await tester.pump();
    await tester.pump();

    expect(adapter.scanCalls, 1);
  });

  testWidgets('Tapping a device connects and lists its services', (
    tester,
  ) async {
    final adapter =
        FakeBleAdapter(
            services: const [
              BleServiceInfo(
                uuid: '180f',
                characteristics: [
                  BleCharacteristicInfo(uuid: '2a19', canRead: true),
                ],
              ),
            ],
          )
          ..readValues = {
            '2a19': [0x64],
          };
    await pumpNearby(tester, adapter);
    adapter.scanController.add([camTrap]);
    await tester.pump();

    await tester.tap(find.text('CamTrap-01'));
    await tester.pumpAndSettle();

    expect(find.byType(DeviceScreen), findsOneWidget);
    expect(adapter.scanCancelled, isTrue, reason: 'scan stops before connect');
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Service 180f'), findsOneWidget);

    await tester.tap(find.text('2a19'));
    await tester.pumpAndSettle();
    expect(find.text('Value: 0x64'), findsOneWidget);

    // Leaving the device screen disconnects.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(adapter.disconnectCalls, 1);
  });

  testWidgets('A failed connection can be retried', (tester) async {
    final adapter = FakeBleAdapter(connectFails: true);
    await pumpNearby(tester, adapter);
    adapter.scanController.add([camTrap]);
    await tester.pump();

    await tester.tap(find.text('CamTrap-01'));
    await tester.pumpAndSettle();

    expect(find.text('Could not connect to the device'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);

    adapter.connectFails = false;
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
  });
}
