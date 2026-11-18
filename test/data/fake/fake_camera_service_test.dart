import 'package:flutter_test/flutter_test.dart';
import 'package:camera_trap_app/data/fake/fake_camera_service.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';

void main() {
  test('Load cameras returns test camera trap objects', () async {
    final FakeCameraService test = FakeCameraService();

    try {
      List<CameraTrap> cameras = await test.loadCameras();
      expect(cameras.length, 3);
      expect(cameras[0].name, 'Camera 1');
      expect(cameras[1].name, 'Camera 2');
      expect(cameras[2].name, 'Camera 3');
    } catch (e) {
      rethrow;
    }

    final FakeCameraService test2 = FakeCameraService(fail: false);

    try {
      List<CameraTrap> cameras = await test2.loadCameras();
    } catch (e) {
      expect(e.toString(), 'Could not load cameras'); 
    }

  });
}