import 'package:camera_trap_app/data/models/camera_trap.dart';
import 'package:flutter/foundation.dart';

/// Every state the camera list can be in. `sealed` lets a `switch` check
/// that all of them are handled.
sealed class CamerasState {
  const CamerasState();
}

final class CamerasLoading extends CamerasState {
  const CamerasLoading();

  @override
  bool operator ==(Object other) => other is CamerasLoading;

  @override
  int get hashCode => (CamerasLoading).hashCode;
}

final class CamerasLoaded extends CamerasState {
  const CamerasLoaded(this.cameras);

  final List<CameraTrap> cameras;

  CameraTrap? byId(String id) =>
      cameras.where((camera) => camera.id == id).firstOrNull;

  @override
  bool operator ==(Object other) =>
      other is CamerasLoaded && listEquals(other.cameras, cameras);

  @override
  int get hashCode => Object.hashAll(cameras);
}

final class CamerasError extends CamerasState {
  const CamerasError(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      other is CamerasError && other.message == message;

  @override
  int get hashCode => message.hashCode;
}
