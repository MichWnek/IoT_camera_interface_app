import 'package:camera_trap_app/data/camera_service.dart';
import 'package:camera_trap_app/data/models/camera_config.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';
import 'package:camera_trap_app/data/models/device_status.dart';

/// Simulated cameras for development and tests, until BLE is available.
class FakeCameraService implements CameraService {
  FakeCameraService({
    List<CameraTrap>? cameras,
    this.delay = const Duration(milliseconds: 1000),
    this.statusInterval = const Duration(seconds: 2),
    this.pingDelay = const Duration(milliseconds: 200),
    this.fail = false,
    this.failApply = false,
  }) : cameras = cameras ?? sampleCameras();

  final List<CameraTrap> cameras;
  final Duration delay;
  final Duration statusInterval;
  final Duration pingDelay;
  final bool fail;
  final bool failApply;

  static List<CameraTrap> sampleCameras() => [
    CameraTrap(
      id: '1',
      name: 'Camera 1',
      bleMac: '00:11:22:33:44:01',
      status: const DeviceStatus(
        batteryPercent: 67,
        sdFreeGb: 0.67,
        isOnline: true,
      ),
    ),
    CameraTrap(
      id: '2',
      name: 'Camera 2',
      bleMac: '00:11:22:33:44:02',
      status: const DeviceStatus(
        batteryPercent: 99,
        sdFreeGb: 0.39,
        isOnline: false,
      ),
    ),
    CameraTrap(id: '3', name: 'Camera 3', bleMac: '00:11:22:33:44:03'),
  ];

  @override
  Future<List<CameraTrap>> loadCameras() async {
    await Future.delayed(delay);
    if (fail) {
      throw Exception('Could not load cameras');
    }
    return cameras;
  }

  /// Online cameras lose 1% battery per [statusInterval] until they reach 0.
  /// Offline and never-connected cameras send nothing.
  @override
  Stream<DeviceStatus> watchStatus(String cameraId) {
    final start = cameras
        .where((camera) => camera.id == cameraId)
        .firstOrNull
        ?.status;
    if (start == null || !start.isOnline) {
      return const Stream.empty();
    }

    // Each listener gets its own copy, so cameras and listeners don't mix.
    var status = start;
    return Stream.periodic(statusInterval, (_) {
      status = status.copyWith(
        batteryPercent: status.batteryPercent - 1,
        lastSeen: DateTime.now(),
      );
      return status;
    }).take(start.batteryPercent);
  }

  @override
  Future<Duration> ping(String cameraId) async {
    final stopwatch = Stopwatch()..start();
    await Future.delayed(pingDelay);
    return stopwatch.elapsed;
  }

  @override
  Future<void> applyConfig(String cameraId, CameraConfig config) async {
    await Future.delayed(delay);
    if (failApply) {
      throw Exception('Could not apply configuration');
    }
  }
}
