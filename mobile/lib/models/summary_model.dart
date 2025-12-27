class Summary {
  final int numBuses;
  final double busKm;
  final double walkKm;
  final double totalMinutes;

  Summary({
    required this.numBuses,
    required this.busKm,
    required this.walkKm,
    required this.totalMinutes,
  });

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      numBuses: json['num_buses'],
      busKm: (json['bus_km'] ?? 0).toDouble(),
      walkKm: (json['walk_km'] ?? 0).toDouble(),
      totalMinutes: (json['total_minutes'] ?? 0).toDouble(),
    );
  }
}
