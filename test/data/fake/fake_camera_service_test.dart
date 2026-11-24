import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:camera_trap_app/data/fake/fake_camera_service.dart';
import 'package:camera_trap_app/data/models/camera_config.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';
import 'package:camera_trap_app/data/models/device_status.dart';

void main() {
  const fastTick = Duration(milliseconds: 1);

  test('Load cameras returns the sample cameras', () async {
    final service = FakeCameraService(delay: Duration.zero);

    final cameras = await service.loadCameras();

    expect(cameras.map((c) => c.name), ['Camera 1', 'Camera 2', 'Camera 3']);
  });

  test('Load cameras throws when the service fails', () async {
    final service = FakeCameraService(fail: true, delay: Duration.zero);

    await expectLater(service.loadCameras(), throwsA(isA<Exception>()));
  });

  test('Ping returns the round trip time', () async {
    final service = FakeCameraService(
      pingDelay: const Duration(milliseconds: 50),
    );

    final rtt = await service.ping('1');

    expect(rtt, greaterThanOrEqualTo(const Duration(milliseconds: 50)));
  });

  test('Slow ping throws timeout exception', () async {
    final service = FakeCameraService(pingDelay: const Duration(seconds: 2));

    await expectLater(
      service.ping('1').timeout(const Duration(seconds: 1)),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('watchStatus emits decreasing battery values', () async {
    final service = FakeCameraService(statusInterval: fastTick);

    // Camera 1 starts at 67%.
    final first3 = await service.watchStatus('1').take(3).toList();

    expect(first3.map((s) => s.batteryPercent), [66, 65, 64]);
    expect(first3.every((s) => s.lastSeen != null), isTrue);
  });

  test('watchStatus stops at 0% instead of going negative', () async {
    final service = FakeCameraService(
      statusInterval: fastTick,
      cameras: [
        CameraTrap(
          id: 'low',
          name: 'Low battery',
          bleMac: '00:00:00:00:00:01',
          status: const DeviceStatus(
            batteryPercent: 2,
            sdFreeGb: 1,
            isOnline: true,
          ),
        ),
      ],
    );

    final all = await service.watchStatus('low').toList();

    expect(all.map((s) => s.batteryPercent), [1, 0]);
  });

  test('watchStatus sends nothing for offline or never connected cameras', () {
    final service = FakeCameraService(statusInterval: fastTick);

    // Camera 2 is offline, camera 3 has never connected.
    expect(service.watchStatus('2'), emitsDone);
    expect(service.watchStatus('3'), emitsDone);
  });

  test('Each listener gets its own status, starting from the camera', () async {
    final service = FakeCameraService(statusInterval: fastTick);

    final a = await service.watchStatus('1').first;
    final b = await service.watchStatus('1').first;

    expect(a.batteryPercent, 66);
    expect(b.batteryPercent, 66);
  });

  test('applyConfig completes, and throws when set to fail', () async {
    const config = CameraConfig(aiThreshold: 0.3, pirThreshold: 1.0);

    await FakeCameraService(delay: Duration.zero).applyConfig('1', config);

    await expectLater(
      FakeCameraService(
        delay: Duration.zero,
        failApply: true,
      ).applyConfig('1', config),
      throwsA(isA<Exception>()),
    );
  });
}
