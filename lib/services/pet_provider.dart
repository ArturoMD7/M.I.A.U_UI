import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/pet_service.dart';

class PetProvider with ChangeNotifier {
  final PetService _petService;
  List<dynamic> _pets = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  DateTime? _lastFetchTime;
  String? _errorMessage;
  String? _currentToken;

  // Tiempo mínimo entre fetches (5 segundos)
  static const Duration _minFetchInterval = Duration(seconds: 5); 

  PetProvider() : _petService = PetService(apiUrl: dotenv.env['API_URL'] ?? 'URL no definida');

  List<dynamic> get pets => _pets;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

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

  Future<void> addPet(Map<String, dynamic> petData, String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _petService.addPet(petData, token);
      await fetchPets(token, forceRefresh: true);
    } catch (e) {
      _errorMessage = _parseError(e);
    } finally {
      _isLoading = false;
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