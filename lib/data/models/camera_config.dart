class CameraConfig {
  // subject to change, needs to be decided by hardware team
  const CameraConfig({
    required this.aiThreshold,
    required this.pirThreshold, // probably voltage
  }) : assert(
         aiThreshold >= 0 && aiThreshold <= 1,
         'aiThreshold must be between 0 and 1',
       ),
       assert(
         pirThreshold >= 0 && pirThreshold <= 3.3,
         'pirThreshold (Volts) must be between 0 and 3.3',
       );

  /// Used until configs can be read back from the camera.
  static const defaults = CameraConfig(aiThreshold: 0.5, pirThreshold: 1.65);

  final double aiThreshold;
  final double pirThreshold;

  @override
  bool operator ==(Object other) =>
      other is CameraConfig &&
      other.aiThreshold == aiThreshold &&
      other.pirThreshold == pirThreshold;

  @override
  int get hashCode => Object.hash(aiThreshold, pirThreshold);

  CameraConfig copyWith({double? aiThreshold, double? pirThreshold}) =>
      CameraConfig(
        aiThreshold: aiThreshold ?? this.aiThreshold,
        pirThreshold: pirThreshold ?? this.pirThreshold,
      );
}
