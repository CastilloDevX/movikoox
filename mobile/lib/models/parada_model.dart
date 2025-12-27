class Parada {
  final String id;
  final String nombre;
  final double latitud;
  final double longitud;
  final List<String> rutas;

  Parada({
    required this.id,
    required this.nombre,
    required this.latitud,
    required this.longitud,
    required this.rutas,
  });

  factory Parada.fromJson(Map<String, dynamic> json) {
    return Parada(
      id: json['id'].toString(),
      nombre: json['nombre'],
      latitud: json['latitud'].toDouble(),
      longitud: json['longitud'].toDouble(),
      rutas: List<String>.from(json['rutas'] ?? []),
    );
  }
}
