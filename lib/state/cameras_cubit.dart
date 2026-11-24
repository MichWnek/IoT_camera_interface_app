import 'dart:async';

import 'package:camera_trap_app/data/camera_service.dart';
import 'package:camera_trap_app/data/models/device_status.dart';
import 'package:camera_trap_app/state/cameras_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// App-wide source of truth for the camera list and each camera's live status.
class CamerasCubit extends Cubit<CamerasState> {
  CamerasCubit(this._service) : super(const CamerasLoading());

  final CameraService _service;
  final List<StreamSubscription<DeviceStatus>> _statusSubscriptions = [];

  /// Loads the cameras, then keeps their status up to date. Also used to retry.
  Future<void> load() async {
    await _cancelStatusSubscriptions();
    emit(const CamerasLoading());

    try {
      final cameras = await _service.loadCameras();
      if (isClosed) return;
      emit(CamerasLoaded(cameras));

      for (final camera in cameras) {
        _statusSubscriptions.add(
          _service
              .watchStatus(camera.id)
              .listen((status) => _onStatus(camera.id, status)),
        );
      }
    } catch (_) {
      if (isClosed) return;
      emit(const CamerasError("Couldn't load cameras"));
    }
  }

  void _onStatus(String cameraId, DeviceStatus status) {
    final current = state;
    if (current is! CamerasLoaded) return;

    emit(
      CamerasLoaded([
        for (final camera in current.cameras)
          camera.id == cameraId ? camera.copyWith(status: status) : camera,
      ]),
    );
  }

  Future<void> _cancelStatusSubscriptions() async {
    for (final subscription in _statusSubscriptions) {
      await subscription.cancel();
    }
    _statusSubscriptions.clear();
  }

  @override
  Future<void> close() async {
    await _cancelStatusSubscriptions();
    return super.close();
  }
}
