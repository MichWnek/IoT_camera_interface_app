class CameraConfig {
  // subject to change, needs to be decided by hardware team
  CameraConfig({
    required this.aiThreshold,
    required this.pirThreshold, // probably voltage
  }) : assert(
         aiThreshold >= 0 && aiThreshold <= 1,
         'aiThreshold must be between 0 and 1',
       );

  double aiThreshold;
  double pirThreshold;

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
