class Instruction {
  final String type; // "walk" | "bus"

  // WALK
  final Map<String, double>? from; // {lat, lon}
  final Map<String, double>? to;   // {lat, lon}

  // BUS
  final String? bus;
  final bool? isEje;
  final Map<String, dynamic>? fromStop;
  final Map<String, dynamic>? toStop;
  final int? stopsCount;

  // COMMON
  final double distanceKm;
  final double minutes;

  Instruction({
    required this.type,
    required this.distanceKm,
    required this.minutes,
    this.from,
    this.to,
    this.bus,
    this.isEje,
    this.fromStop,
    this.toStop,
    this.stopsCount,
  });

  factory Instruction.fromJson(Map<String, dynamic> json) {
    return Instruction(
      type: json['type'],
      bus: json['bus'],
      isEje: json['isEje'],
      from: json['from'] != null
          ? {
              "lat": json['from']['lat'].toDouble(),
              "lon": json['from']['lon'].toDouble(),
            }
          : null,
      to: json['to'] != null
          ? {
              "lat": json['to']['lat'].toDouble(),
              "lon": json['to']['lon'].toDouble(),
            }
          : null,
      fromStop: json['from_stop'],
      toStop: json['to_stop'],
      stopsCount: json['stops_count'],
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      minutes: (json['minutes'] ?? 0).toDouble(),
    );
  }
}
