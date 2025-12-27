class Instruction {
  final String type;
  final String? bus;
  final int? stopsCount;
  final double distanceKm;
  final double minutes;

  Instruction({
    required this.type,
    this.bus,
    this.stopsCount,
    required this.distanceKm,
    required this.minutes,
  });

  factory Instruction.fromJson(Map<String, dynamic> json) {
    return Instruction(
      type: json['type'],
      bus: json['bus'],
      stopsCount: json['stops_count'],
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      minutes: (json['minutes'] ?? 0).toDouble(),
    );
  }
}
