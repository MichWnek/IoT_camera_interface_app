import 'package:camera_trap_app/data/models/device_status.dart';

class CameraTrap {
  CameraTrap({
    required this.id,
    required this.name,
    required this.bleMac,
    this.status,
  });

  String id;
  String name;
  String bleMac;

  DeviceStatus? status;

  @override
  bool operator ==(Object other) =>
      other is CameraTrap &&
      other.id == id &&
      other.name == name &&
      other.bleMac == bleMac &&
      other.status == status;

  @override
  int get hashCode => Object.hash(id, name, bleMac);

  CameraTrap copyWith({
    String? id,
    String? name,
    String? bleMac,
    DeviceStatus? status,
  }) => CameraTrap(
    id: id ?? this.id,
    name: name ?? this.name,
    bleMac: bleMac ?? this.bleMac,
    status: status ?? this.status,
  );
}
