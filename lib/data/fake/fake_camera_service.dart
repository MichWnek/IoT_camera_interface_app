import 'package:camera_trap_app/data/models/camera_trap.dart';
import 'package:camera_trap_app/data/models/device_status.dart';

class FakeCameraService {
  FakeCameraService({
    this.delay = const Duration(milliseconds: 1000),
    this.pingDelay = const Duration(milliseconds: 200),
    this.fail = false,
    this.cameraStatus = const DeviceStatus(
      batteryPercent: 90,
      isOnline: true,
      sdFreeGb: 0.9,
    ),
  });

  final Duration delay;
  final Duration pingDelay;
  final bool fail;
  DeviceStatus cameraStatus;

  Future<List<CameraTrap>> loadCameras() async {
    await Future.delayed(delay);
    if (fail) {
      throw Exception('Could not load cameras');
    }

    return [
      CameraTrap(
        id: '1',
        name: 'Camera 1',
        bleMac: '00:11:22:33:44:55',
        status: const DeviceStatus(
          batteryPercent: 67,
          sdFreeGb: 0.67,
          isOnline: true,
        ),
      ),
      CameraTrap(
        id: '2',
        name: 'Camera 2',
        bleMac: '00:11:22:33:44:55',
        status: const DeviceStatus(
          batteryPercent: 99,
          sdFreeGb: 0.39385787395,
          isOnline: false,
        ),
      ),
      CameraTrap(
        id: '3',
        name: 'Camera 3',
        bleMac: '00:11:22:33:44:55',
        status: null,
      ),
    ];
  }

  Stream<DeviceStatus> watchStatus(String cameraId) async* {
    while (cameraStatus.batteryPercent > 0) {
      await Future.delayed(delay);
      cameraStatus = cameraStatus.copyWith(
        batteryPercent: cameraStatus.batteryPercent - 1,
        lastSeen: DateTime.now(),
      );
      yield cameraStatus;
    }
  }

  Future<Duration> ping() async {
    final stopwatch = Stopwatch()..start();
    await Future.delayed(pingDelay);
    return stopwatch.elapsed;
  }
}
