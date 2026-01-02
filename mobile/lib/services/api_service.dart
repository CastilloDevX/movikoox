import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/parada_model.dart';
import '../models/ruta_model.dart';
import '../models/instruction_model.dart';
import '../models/summary_model.dart';

class ApiService {
  static const String baseUrl = 'https://movikoox.vercel.app/api/v1';

  // -------------------------
  // PARADAS
  // -------------------------

  static Future<List<Parada>> getParadas() async {
    final response = await http.get(Uri.parse('$baseUrl/paradas'));
    final data = jsonDecode(response.body);

    return List<Parada>.from(data.map((e) => Parada.fromJson(e)));
  }

  static Future<Parada> getParadaById(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/paradas/$id'));
    return Parada.fromJson(jsonDecode(response.body));
  }

  static Future<Map<String, dynamic>> getParadaCercana(
    double lat,
    double lon,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/paradas/cercana?latitud=$lat&longitud=$lon'),
    );
    return jsonDecode(response.body);
  }

  static Future<List<Parada>> getParadasPorRuta(String nombre) async {
    final response = await http.get(Uri.parse('$baseUrl/paradas/bus/$nombre'));

    final Map<String, dynamic> json = jsonDecode(response.body);

    final List<dynamic> body = json['body'];

    return body.map<Parada>((e) => Parada.fromJson(e)).toList();
  }

  // -------------------------
  // RUTAS
  // -------------------------
  static Future<List<Ruta>> getRutas() async {
    final response = await http.get(Uri.parse('$baseUrl/rutas'));
    final Map<String, dynamic> json = jsonDecode(response.body);

    final List<dynamic> body = json['body'];

    return body.map<Ruta>((rutaJson) {
      return Ruta(
        nombre: rutaJson['nombre'],
        paradas: (rutaJson['paradas'] as List)
            .map((p) => Parada.fromJson(p))
            .toList(),
      );
    }).toList();
  }

  // -------------------------
  // INSTRUCCIONES
  // -------------------------

  static Future<Map<String, dynamic>> getInstrucciones({
    required double inicioLat,
    required double inicioLon,
    required double destinoLat,
    required double destinoLon,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/instrucciones'
      '?inicio=$inicioLat,$inicioLon'
      '&destino=$destinoLat,$destinoLon',
    );

    final response = await http.get(uri);
    final json = jsonDecode(response.body);

    return {
      'instructions': List<Instruction>.from(
        json['instructions'].map((e) => Instruction.fromJson(e)),
      ),
      'summary': Summary.fromJson(json['summary']),
    };
  }
}
