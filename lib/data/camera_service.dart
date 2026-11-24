import 'package:camera_trap_app/data/models/camera_config.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';
import 'package:camera_trap_app/data/models/device_status.dart';

/// Everything the app needs from the cameras.
///
/// The UI and state only depend on this interface, so the fake can be
/// swapped for the real BLE implementation without touching any screen.
abstract interface class CameraService {
  /// The cameras the user has added.
  Future<List<CameraTrap>> loadCameras();

  /// Live status updates for one camera, for as long as it's listened to.
  Stream<DeviceStatus> watchStatus(String cameraId);

  /// Round trip time of a "hello" echo to the camera.
  Future<Duration> ping(String cameraId);

  /// Sends a new configuration to the camera.
  Future<void> applyConfig(String cameraId, CameraConfig config);
}
