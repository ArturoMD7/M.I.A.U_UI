import 'dart:convert';
import 'package:http/http.dart' as http;

class PetService {
  final String baseUrl =
      "http://192.168.1.95:8000/api/pets/"; // Reemplaza con tu URL base

  Future<List<dynamic>> getPets(String token) async {
    final response = await http.get(
      Uri.parse(baseUrl),
      headers: {
        'Authorization': 'Bearer $token', // Incluir el token en los headers
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load pets: ${response.body}');
    }
  }

  Future<void> addPet(Map<String, dynamic> petData, String token) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token', // Incluir el token en los headers
      },
      body: jsonEncode(petData),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add pet: ${response.body}');
    }
  }
}
