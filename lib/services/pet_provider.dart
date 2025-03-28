import 'package:flutter/material.dart';
import '../services/pet_service.dart';

class PetProvider with ChangeNotifier {
  final PetService _petService = PetService();
  List<dynamic> _pets = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  List<dynamic> get pets => _pets;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;

  Future<void> fetchPets(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      _pets = await _petService.getPets(token);
      _hasLoaded = true;
    } catch (e) {
      throw Exception('Failed to fetch pets: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPet(Map<String, dynamic> petData, String token) async {
    try {
      await _petService.addPet(petData, token);
      await fetchPets(
        token,
      ); // Recargar la lista de mascotas después de agregar una nueva
    } catch (e) {
      throw Exception('Failed to add pet: $e');
    }
  }
}