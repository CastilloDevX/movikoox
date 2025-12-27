class Ruta {
  final String nombre;
  final List<String> paradas;

  Ruta({
    required this.nombre,
    required this.paradas,
  });

  factory Ruta.fromJson(Map<String, dynamic> json) {
    return Ruta(
      nombre: json['nombre'],
      paradas: List<String>.from(json['paradas']),
    );
  }
}
