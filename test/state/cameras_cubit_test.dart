import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:camera_trap_app/data/camera_service.dart';
import 'package:camera_trap_app/data/models/camera_config.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';
import 'package:camera_trap_app/data/models/device_status.dart';
import 'package:camera_trap_app/state/cameras_cubit.dart';
import 'package:camera_trap_app/state/cameras_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// A service the test controls completely: it decides when loading fails
/// and pushes status updates by hand.
class _ControlledService implements CameraService {
  _ControlledService(this.cameras);

  final List<CameraTrap> cameras;
  bool fail = false;
  final Map<String, StreamController<DeviceStatus>> statusControllers = {};

  @override
  Future<List<CameraTrap>> loadCameras() async {
    if (fail) throw Exception('load failed');
    return cameras;
  }

  @override
  Stream<DeviceStatus> watchStatus(String cameraId) =>
      (statusControllers[cameraId] ??= StreamController.broadcast()).stream;

  @override
  Future<Duration> ping(String cameraId) async => Duration.zero;

  @override
  Future<void> applyConfig(String cameraId, CameraConfig config) async {}
}

void main() {
  const statusA = DeviceStatus(batteryPercent: 50, sdFreeGb: 1, isOnline: true);
  const statusB = DeviceStatus(batteryPercent: 49, sdFreeGb: 1, isOnline: true);

  late List<CameraTrap> cameras;
  late _ControlledService service;

  setUp(() {
    cameras = [
      CameraTrap(id: '1', name: 'One', bleMac: 'AA', status: statusA),
      CameraTrap(id: '2', name: 'Two', bleMac: 'BB'),
    ];
    service = _ControlledService(cameras);
  });

  test('starts in the loading state', () {
    expect(CamerasCubit(service).state, const CamerasLoading());
  });

  blocTest<CamerasCubit, CamerasState>(
    'load emits loading, then the cameras',
    build: () => CamerasCubit(service),
    act: (cubit) => cubit.load(),
    expect: () => [const CamerasLoading(), CamerasLoaded(cameras)],
  );

  blocTest<CamerasCubit, CamerasState>(
    'load emits an error when the service fails',
    build: () => CamerasCubit(service..fail = true),
    act: (cubit) => cubit.load(),
    expect: () => [
      const CamerasLoading(),
      const CamerasError("Couldn't load cameras"),
    ],
  );

  blocTest<CamerasCubit, CamerasState>(
    'retrying after an error loads the cameras',
    build: () => CamerasCubit(service..fail = true),
    act: (cubit) async {
      await cubit.load();
      service.fail = false;
      await cubit.load();
    },
    skip: 2, // the first, failed attempt
    expect: () => [const CamerasLoading(), CamerasLoaded(cameras)],
  );

  test('a status update replaces only that camera\'s status', () async {
    final cubit = CamerasCubit(service);
    await cubit.load();

    service.statusControllers['1']!.add(statusB);
    await Future<void>.delayed(Duration.zero);

    final state = cubit.state as CamerasLoaded;
    expect(state.byId('1')!.status, statusB);
    expect(state.byId('2')!.status, isNull);
    await cubit.close();
  });

  test('closing the cubit stops listening for status updates', () async {
    final cubit = CamerasCubit(service);
    await cubit.load();
    expect(service.statusControllers['1']!.hasListener, isTrue);

    await cubit.close();

    expect(service.statusControllers['1']!.hasListener, isFalse);
  });

  test('loading again replaces the old status subscriptions', () async {
    final cubit = CamerasCubit(service);
    await cubit.load();
    await cubit.load();

    // Still exactly one listener per camera, not two.
    service.statusControllers['1']!.add(statusB);
    await Future<void>.delayed(Duration.zero);
    expect((cubit.state as CamerasLoaded).byId('1')!.status, statusB);

    await cubit.close();
    expect(service.statusControllers['1']!.hasListener, isFalse);
  });
}
