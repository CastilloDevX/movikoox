import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodeService {
  static const String baseUrl = "https://nominatim.openstreetmap.org/search";

  Future<List<dynamic>> searchPlaces(String query) async {
    final encoded = Uri.encodeComponent("$query, Campeche, Campeche, México");

    final url = Uri.parse(
      "$baseUrl?q=$encoded&format=json&addressdetails=1&limit=10"
    );

    final response = await http.get(
      url,
      headers: {"User-Agent": "Koox-App"} // obligatorio para Nominatim
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }

    return [];
  }
}