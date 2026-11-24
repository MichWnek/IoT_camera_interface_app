import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:camera_trap_app/data/fake/fake_camera_service.dart';
import 'package:camera_trap_app/data/models/device_status.dart';

void main() {
  test('Load cameras returns test camera trap objects', () async {
    final service = FakeCameraService(delay: Duration.zero);

    final cameras = await service.loadCameras();

    expect(cameras.length, 3);
    expect(cameras[0].name, 'Camera 1');
    expect(cameras[1].name, 'Camera 2');
    expect(cameras[2].name, 'Camera 3');
  });

  test('Load cameras throws when the service fails', () async {
    final service = FakeCameraService(fail: true, delay: Duration.zero);

    await expectLater(service.loadCameras(), throwsA(isA<Exception>()));
  });

  test('Ping returns the round trip time', () async {
    final service = FakeCameraService(
      pingDelay: const Duration(milliseconds: 50),
    );

    final rtt = await service.ping();

    expect(rtt, greaterThanOrEqualTo(const Duration(milliseconds: 50)));
  });

  test('Slow ping throws timeout exception', () async {
    final service = FakeCameraService(pingDelay: const Duration(seconds: 2));

    await expectLater(
      service.ping().timeout(const Duration(seconds: 1)),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('watchStatus emits decreasing battery values', () async {
    const testCam = DeviceStatus(
      batteryPercent: 90,
      isOnline: true,
      sdFreeGb: 0.9,
    );
    final service = FakeCameraService(
      cameraStatus: testCam,
      delay: Duration.zero,
    );

    final first3 = await service.watchStatus('1').take(3).toList();

    expect(first3.map((s) => s.batteryPercent), [89, 88, 87]);
    expect(first3.every((s) => s.lastSeen != null), isTrue);
  });

  test('watchStatus stops at 0% instead of going negative', () async {
    const nearlyEmpty = DeviceStatus(
      batteryPercent: 2,
      isOnline: true,
      sdFreeGb: 0.9,
    );
    final service = FakeCameraService(
      cameraStatus: nearlyEmpty,
      delay: Duration.zero,
    );

    final all = await service.watchStatus('1').toList();

    expect(all.map((s) => s.batteryPercent), [1, 0]);
  });
}
