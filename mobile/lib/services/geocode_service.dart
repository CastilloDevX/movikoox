import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodeService {
  static const String baseUrl = "https://nominatim.openstreetmap.org/search";

  Future<List<dynamic>> searchPlaces(String query) async {
    final encoded = Uri.encodeComponent(
      "$query, Municipio de Campeche, Campeche, México",
    );

    final url = Uri.parse(
      "$baseUrl?q=$encoded&format=json&addressdetails=1&limit=10",
    );

    final response = await http.get(
      url,
      headers: {"User-Agent": "Movikoox-App"}, // obligatorio para Nominatim
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }

    return [];
  }

  // -----------------------------
  // REVERSE GEOCODING
  // -----------------------------
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/reverse"
      "?lat=$latitude"
      "&lon=$longitude"
      "&format=json"
      "&addressdetails=1",
    );

    final response = await http.get(
      url,
      headers: {"User-Agent": "Movikoox-App"},
    );

    if (response.statusCode != 200) return null;

    final data = json.decode(response.body);    
    final address = data["address"];

    if (address == null) return null;

    final street = address["road"];
    final houseNumber = address["house_number"];
    final suburb =
        address["suburb"] ?? address["neighbourhood"] ?? address["quarter"];

    String result = "";

    if (street != null) {
      result += street;
    }

    if (houseNumber != null) {
      result += " #$houseNumber";
    }

    if (suburb != null) {
      result += " ($suburb)";
    }

    return result.isNotEmpty ? result : null;
  }
}
