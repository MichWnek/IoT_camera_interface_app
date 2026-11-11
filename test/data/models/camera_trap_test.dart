import 'package:flutter_test/flutter_test.dart';
import 'package:camera_trap_app/data/models/camera_trap.dart';

void main() {
  test('Two CameraTrap objects with same values are equal', () {
    final trap1 = CameraTrap(
      id: '1',
      name: 'Camera 1',
      bleMac: '00:11:22:33:44:55',
      status: null,
    );
    final trap2 = CameraTrap(
      id: '1',
      name: 'Camera 1',
      bleMac: '00:11:22:33:44:55',
      status: null,
    );
    expect(trap1, equals(trap2));
  });

  test('Two CameraTrap objects with different values are not equal', () {
    final trap1 = CameraTrap(
      id: '1',
      name: 'Camera 1',
      bleMac: '00:11:22:33:44:55',
      status: null,
    );
    final trap2 = CameraTrap(
      id: '2',
      name: 'Camera 2',
      bleMac: '66:77:88:99:AA:BB',
      status: null,
    );
    expect(trap1, isNot(equals(trap2)));
  });

  test('CopyWith creates a new CameraTrap with updated values', () {
    final trap1 = CameraTrap(
      id: '1',
      name: 'Camera 1',
      bleMac: '00:11:22:33:44:55',
      status: null,
    );
    final trap2 = trap1.copyWith(name: 'Camera 2');
    expect(trap2.id, equals('1'));
    expect(trap2.name, equals('Camera 2'));
    expect(trap2.bleMac, equals('00:11:22:33:44:55'));
    expect(trap2.status, isNull);
  });

  test('No DeviceStatus required for CameraTrap', () {
    final trap = CameraTrap(
      id: '1',
      name: 'Camera 1',
      bleMac: '00:11:22:33:44:55',
      status: null,
    );
    expect(trap.status, isNull);
  });
}
