import 'package:flutter_test/flutter_test.dart';
import 'package:camera_trap_app/data/models/device_status.dart';

void main() {
  test('Two DeviceStatus objects with same values are equal', () {
    final status1 = const DeviceStatus(
      isOnline: true,
      batteryPercent: 80,
      sdFreeGb: 1.5,
    );
    final status2 = const DeviceStatus(
      isOnline: true,
      batteryPercent: 80,
      sdFreeGb: 1.5,
    );
    expect(status1, equals(status2));
  });

  test('Two DeviceStatus objects with different values are not equal', () {
    final status1 = const DeviceStatus(
      isOnline: true,
      batteryPercent: 80,
      sdFreeGb: 1.5,
    );
    final status2 = const DeviceStatus(
      isOnline: false,
      batteryPercent: 80,
      sdFreeGb: 1.5,
    );
    expect(status1, isNot(equals(status2)));
  });

  test('CopyWith creates a new DeviceStatus with updated values', () {
    final status1 = const DeviceStatus(
      isOnline: true,
      batteryPercent: 80,
      sdFreeGb: 1.5,
    );
    final status2 = status1.copyWith(batteryPercent: 90);
    expect(status2.isOnline, equals(true));
    expect(status2.batteryPercent, equals(90));
    expect(status2.sdFreeGb, equals(1.5));
  });

  test('Battery percent bounds are respected', () {
    expect(
      () => DeviceStatus(isOnline: true, batteryPercent: 113, sdFreeGb: 2.0),
      throwsA(isA<AssertionError>()),
    );

    expect(
      () => DeviceStatus(isOnline: true, batteryPercent: -10, sdFreeGb: 2.0),
      throwsA(isA<AssertionError>()),
    );
  });

  test('isLowBattery returns true for batteryPercent < 20', () {
    final a = const DeviceStatus(
      isOnline: true,
      batteryPercent: 19,
      sdFreeGb: 1.5,
    );
    expect(a.isLowBattery, isTrue);

    final b = const DeviceStatus(
      isOnline: true,
      batteryPercent: 20,
      sdFreeGb: 1.5,
    );
    expect(b.isLowBattery, isFalse);
    final c = const DeviceStatus(
      isOnline: true,
      batteryPercent: 21,
      sdFreeGb: 1.5,
    );
    expect(c.isLowBattery, isFalse);
  });
}
