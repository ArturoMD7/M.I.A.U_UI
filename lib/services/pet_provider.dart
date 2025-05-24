import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/pet_service.dart';
import '../screens/add_pet_screen.dart';

class PetProvider with ChangeNotifier {
  final PetService _petService;
  List<dynamic> _pets = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  DateTime? _lastFetchTime;
  String? _errorMessage;
  String? _currentToken;
  final Map<String, String> _typeOptions = {
    'Perro': 'Perro',
    'Gato': 'Gato', 
    'Ave': 'Ave',
    'Roedor': 'Roedor',
    'Otro': 'Otro'
  };

  // Tiempo mínimo entre fetches (5 segundos)
  static const Duration _minFetchInterval = Duration(seconds: 5); 

  PetProvider() : _petService = PetService(apiUrl: dotenv.env['API_URL'] ?? 'URL no definida');

  List<dynamic> get pets => _pets;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  void removePet(int petId) {
    _pets.removeWhere((pet) => pet['id'] == petId);
    notifyListeners(); // Esto es crucial para actualizar la UI
  }

  Future<void> fetchPets(String token, {bool forceRefresh = false}) async {
    // 1. Validar si ya está cargando o no necesita recargar
    if (_isLoading) return;
    
    final now = DateTime.now();
    if (!forceRefresh && 
        _lastFetchTime != null && 
        now.difference(_lastFetchTime!) < _minFetchInterval) {
      return;
    }

    // 2. Solo hacer fetch si el token cambió o si es forzado
    if (!forceRefresh && _currentToken == token && _hasLoaded) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final startTime = DateTime.now();
      
      _pets = await _petService.getPets(token);
      _currentToken = token;
      _hasLoaded = true;
      _lastFetchTime = DateTime.now();
      
      debugPrint('Pet fetch completed in ${_lastFetchTime!.difference(startTime).inMilliseconds}ms');
    } catch (e) {
      _errorMessage = _parseError(e);
      debugPrint('Error fetching pets: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  
void addPet(Map<String, dynamic> newPet) {
  // Convertir edad de número a texto si es necesario
  if (newPet['age'] is int) {
    newPet['age'] = {
      0: 'Cachorro',
      1: 'Joven',
      2: 'Adulto',
    }[newPet['age']] ?? 'Cachorro';
  }
  
  // Convertir breed de número a texto si es necesario
  if (newPet['breed'] is int) {
    final breedIndex = newPet['breed'];
    newPet['breed'] = _typeOptions.keys.toList().elementAtOrNull(breedIndex) ?? 'Perro';
  }
  
  _pets.insert(0, newPet);
  notifyListeners();
}

void updatePet(Map<String, dynamic> updatedPet) {
  // Misma conversión que en addPet
  if (updatedPet['age'] is int) {
    updatedPet['age'] = {
      0: 'Cachorro',
      1: 'Joven',
      2: 'Adulto',
    }[updatedPet['age']] ?? 'Cachorro';
  }
  
  if (updatedPet['breed'] is int) {
    final breedIndex = updatedPet['breed'];
    updatedPet['breed'] = _typeOptions.keys.toList().elementAtOrNull(breedIndex) ?? 'Perro';
  }

  final index = _pets.indexWhere((pet) => pet['id'] == updatedPet['id']);
  if (index != -1) {
    _pets[index] = updatedPet;
    notifyListeners();
  }
}
  String _parseError(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Método para limpiar el caché cuando el usuario cierra sesión
  void clearCache() {
    _pets = [];
    _hasLoaded = false;
    _lastFetchTime = null;
    _currentToken = null;
    _errorMessage = null;
  }
}