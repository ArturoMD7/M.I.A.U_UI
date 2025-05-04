import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PetService {
  final String apiUrl;
  final _throttleTimers = <String, Timer>{};

  PetService({required this.apiUrl});

  Future<List<dynamic>> getPets(String token) async {
    final url = Uri.parse('$apiUrl/pets/');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load pets: ${response.body}');
    }
  }

  Future<void> addPet(Map<String, dynamic> petData, String token) async {
    final url = Uri.parse('$apiUrl/pets/');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(petData),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add pet: ${response.body}');
    }
  }

  // Cancelar peticiones pendientes al destruir el servicio
  void dispose() {
    _throttleTimers.forEach((key, timer) => timer.cancel());
    _throttleTimers.clear();
  }
}