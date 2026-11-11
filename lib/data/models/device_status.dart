class DeviceStatus {
  const DeviceStatus({
    required this.batteryPercent,
    required this.sdFreeGb,
    this.isOnline = false,
    this.lastSeen,
  }) : assert(
         0 <= batteryPercent && batteryPercent <= 100,
         'batteryPercent must be between 0 and 100',
       ),
       assert(sdFreeGb >= 0, 'sdFreeGb must be non-negative');

  final int batteryPercent;
  final double sdFreeGb;
  final bool isOnline;
  final DateTime? lastSeen;

  static const int lowBatteryPercent = 20;
  bool get isLowBattery => batteryPercent <= lowBatteryPercent;

  @override
  bool operator ==(Object other) =>
      other is DeviceStatus &&
      other.batteryPercent == batteryPercent &&
      other.sdFreeGb == sdFreeGb &&
      other.isOnline == isOnline;

  @override
  int get hashCode => Object.hash(batteryPercent, sdFreeGb, isOnline);

  DeviceStatus copyWith({
    int? batteryPercent,
    double? sdFreeGb,
    bool? isOnline,
  }) => DeviceStatus(
    batteryPercent: batteryPercent ?? this.batteryPercent,
    sdFreeGb: sdFreeGb ?? this.sdFreeGb,
    isOnline: isOnline ?? this.isOnline,
  );
}
