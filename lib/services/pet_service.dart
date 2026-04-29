import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PetService {
  final String apiUrl;
  final _throttleTimers = <String, Timer>{};

  PetService({required this.apiUrl});

  dynamic _parseResponse(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('data')) {
        return decoded['data'];
      }
      final listValues = decoded.values.whereType<List>().toList();
      if (listValues.isNotEmpty) {
        return listValues.first;
      }
      return decoded;
    }
    return decoded;
  }

  Future<List<dynamic>> getPets(String token) async {
    final url = Uri.parse('$apiUrl/pets/my-pets/');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final result = _parseResponse(decoded);
      if (result is List) {
        return result;
      }
      return [];
    } else {
      throw Exception('Failed to load pets: ${response.body}');
    }
  }

  Future<Map<String, dynamic>?> getPetById(String token, int petId) async {
    final url = Uri.parse('$apiUrl/pets/$petId/');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('data')) {
          return decoded['data'] as Map<String, dynamic>?;
        }
        return decoded;
      }
      return null;
    } else {
      throw Exception('Failed to load pet: ${response.body}');
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

  void dispose() {
    _throttleTimers.forEach((key, timer) => timer.cancel());
    _throttleTimers.clear();
  }
}
