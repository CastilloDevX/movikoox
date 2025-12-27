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

    return List<Parada>.from(
      data.map((e) => Parada.fromJson(e)),
    );
  }

  static Future<Parada> getParadaById(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/paradas/$id'));
    return Parada.fromJson(jsonDecode(response.body));
  }

  static Future<Map<String, dynamic>> getParadaCercana(
      double lat, double lon) async {
    final response = await http.get(
      Uri.parse('$baseUrl/paradas/cercana?latitud=$lat&longitud=$lon'),
    );
    return jsonDecode(response.body);
  }

  static Future<List<Parada>> getParadasPorRuta(String nombre) async {
    final response =
        await http.get(Uri.parse('$baseUrl/paradas/bus/$nombre'));
    final data = jsonDecode(response.body);

    return List<Parada>.from(
      data.map((e) => Parada.fromJson(e)),
    );
  }

  // -------------------------
  // RUTAS
  // -------------------------

  static Future<List<Ruta>> getRutas() async {
    final response = await http.get(Uri.parse('$baseUrl/rutas'));
    final data = jsonDecode(response.body);

    return List<Ruta>.from(
      data.map((e) => Ruta.fromJson(e)),
    );
  }

  // -------------------------
  // INSTRUCCIONES (CORE)
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
        json['instructions'].map(
          (e) => Instruction.fromJson(e),
        ),
      ),
      'summary': Summary.fromJson(json['summary']),
    };
  }
}
