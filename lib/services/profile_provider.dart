import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ProfileState {
  final bool isLoading;
  final Map<String, dynamic>? userInfo;
  final String? errorMessage;

  ProfileState({
    this.isLoading = false,
    this.userInfo,
    this.errorMessage,
  });

  ProfileState copyWith({
    String? profilePhotoUrl,
    bool? isLoading,
    Map<String, dynamic>? userInfo,
    String? errorMessage,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      userInfo: userInfo ?? this.userInfo,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ProfileProvider with ChangeNotifier {
  ProfileState _state = ProfileState();
  ProfileState get state => _state;

  final String baseUrl = dotenv.env['API_URL'] ?? 'http://192.168.1.133:8000/';
  File? _imageFile;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> initialize() async {
    if (_state.userInfo != null) return;
    
    await _loadProfilePhotoUrl();
    await _loadUserInfo();
  }

  Future<void> uploadImage() async {
    if (_imageFile == null) return;

    _updateState(isLoading: true, errorMessage: null);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final token = await _getToken();

      if (userId == null || token == null) {
        _updateState(errorMessage: 'No autenticado');
        return;
      }

      // Crear una marca de tiempo única para evitar caché
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'profile_${userId}_$timestamp.jpg';

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/users/update-profile-photo/'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(
          'profilePhoto',
          _imageFile!.path,
          filename: filename,
        ));

      var response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final data = jsonDecode(responseData);

        if (data['profilePhoto'] != null) {
          // Manejar tanto URLs relativas como absolutas
          String imageUrl = data['profilePhoto'];
          
          // Si es una URL relativa, añadir el baseUrl
          if (!imageUrl.startsWith('http')) {
            imageUrl = '$baseUrl${imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl}';
          }

          // Añadir timestamp para evitar caché
          final cachedImageUrl = '$imageUrl?$timestamp';
          
          await prefs.setString('profilePhotoUrl_$userId', imageUrl);
          
          _updateState(
            profilePhotoUrl: cachedImageUrl,
            errorMessage: null,
          );
        }
      } else {
        _updateState(errorMessage: 'Error subiendo imagen: ${response.statusCode}');
      }
    } catch (e) {
      _updateState(errorMessage: 'Error de conexión: ${e.toString()}');
    } finally {
      _updateState(isLoading: false);
    }
  }

  Future<void> _loadProfilePhotoUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) return;

      final savedUrl = prefs.getString('profilePhotoUrl_$userId');
      if (savedUrl != null) {
        // Añadir timestamp para evitar caché
        final cachedUrl = '$savedUrl?${DateTime.now().millisecondsSinceEpoch}';
        _updateState(profilePhotoUrl: cachedUrl);
      }
    } catch (e) {
      _updateState(errorMessage: 'Error cargando foto de perfil: ${e.toString()}');
    }
  }

  Future<void> _loadUserInfo() async {
    _updateState(isLoading: true, errorMessage: null);
    
    try {
      final token = await _getToken();
      if (token == null) {
        _updateState(errorMessage: 'No autenticado');
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users/me/'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final userInfo = jsonDecode(response.body);
        _updateState(userInfo: userInfo);
        
        // Guardar userId
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', userInfo['id']?.toString() ?? '');
      } else {
        _updateState(errorMessage: 'Error cargando información');
      }
    } on TimeoutException {
      _updateState(errorMessage: 'Tiempo de espera agotado');
    } catch (e) {
      _updateState(errorMessage: 'Error de conexión');
    } finally {
      _updateState(isLoading: false);
    }
  }

  Future<void> pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
        await uploadImage();
      }
    } catch (e) {
      _updateState(errorMessage: 'Error seleccionando imagen');
    }
  }
  
  Future<void> logout(BuildContext context) async {
    _updateState(isLoading: true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = await _getToken();
      final refreshToken = prefs.getString('refresh_token');
      final userId = prefs.getString('userId');

      if (token != null && refreshToken != null) {
        await http.post(
          Uri.parse('$baseUrl/users/logout/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'refresh': refreshToken}),
        );
      }

      // Limpiar datos
      await prefs.remove('jwt_token');
      await prefs.remove('refresh_token');
      await prefs.remove('userId');
      if (userId != null) await prefs.remove('profilePhotoUrl_$userId');

      if (!_isDisposed) {
        _updateState(
          profilePhotoUrl: null,
          userInfo: null,
          isLoading: false,
        );
      }

      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      _updateState(isLoading: false, errorMessage: 'Error cerrando sesión');
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  void _updateState({
    String? profilePhotoUrl,
    bool? isLoading,
    Map<String, dynamic>? userInfo,
    String? errorMessage,
  }) {
    if (_isDisposed) return;
    
    _state = _state.copyWith(
      profilePhotoUrl: profilePhotoUrl,
      isLoading: isLoading,
      userInfo: userInfo,
      errorMessage: errorMessage,
    );
    notifyListeners();
  }
}