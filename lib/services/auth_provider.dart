import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider with ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  String? _token;
  String? _refreshToken;
  String? _userId;
  String? _userEmail;
  Map<String, dynamic>? _userData;

  AuthStatus get status => _status;
  String? get token => _token;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  Map<String, dynamic>? get userData => _userData;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> checkAuth() async {
    _status = AuthStatus.unknown;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('jwt_token');
      _refreshToken = prefs.getString('refresh_token');
      _userId = prefs.getString('user_id');
      _userEmail = prefs.getString('user_email');

      if (_token == null || _token!.isEmpty) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      final result = await apiService.get('/users/me/');

      if (result.success && result.data != null) {
        final data = result.data!;
        if (data.containsKey('data')) {
          _userData = data['data'] as Map<String, dynamic>?;
        } else {
          _userData = data;
        }

        final id = _userData?['id']?.toString() ?? _userId;
        if (id != null && id.isNotEmpty) {
          await prefs.setString('user_id', id);
          _userId = id;
        }

        final email = _userData?['email']?.toString() ?? _userEmail ?? '';
        if (email.isNotEmpty) {
          await prefs.setString('user_email', email);
          await prefs.setString('user_state', _userData?['state']?.toString() ?? '');
          await prefs.setString('user_city', _userData?['city']?.toString() ?? '');
          _userEmail = email;
        }

        _status = AuthStatus.authenticated;
      } else {
        final refreshed = await _tryRefreshToken();
        if (!refreshed) {
          await _clearSession();
          _status = AuthStatus.unauthenticated;
        }
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<bool> _tryRefreshToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;

    try {
      final result = await apiService.post(
        '/users/token/refresh/',
        body: {'refresh': _refreshToken},
        requiresAuth: false,
      );

      if (result.success && result.data != null) {
        final newAccess = result.data!['access']?.toString();
        if (newAccess != null && newAccess.isNotEmpty) {
          _token = newAccess;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', newAccess);

          final meResult = await apiService.get('/users/me/');
          if (meResult.success && meResult.data != null) {
            final data = meResult.data!;
            _userData = data.containsKey('data')
                ? data['data'] as Map<String, dynamic>?
                : data;
            _status = AuthStatus.authenticated;
            notifyListeners();
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }

  Future<void> login(String accessToken, String refreshToken, Map<String, dynamic>? userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);

    _token = accessToken;
    _refreshToken = refreshToken;

    if (userData != null) {
      final id = userData['id']?.toString() ?? '';
      final email = userData['email']?.toString() ?? '';
      await prefs.setString('user_id', id);
      await prefs.setString('user_email', email);
      if (userData['state'] != null) {
        await prefs.setString('user_state', userData['state'].toString());
      }
      if (userData['city'] != null) {
        await prefs.setString('user_city', userData['city'].toString());
      }
      _userId = id;
      _userEmail = email;
    }

    final meResult = await apiService.get('/users/me/');
    if (meResult.success && meResult.data != null) {
      final data = meResult.data!;
      _userData = data.containsKey('data') ? data['data'] as Map<String, dynamic>? : data;
    } else if (userData != null) {
      _userData = userData;
    }

    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout(BuildContext? context) async {
    await _clearSession();
    _status = AuthStatus.unauthenticated;
    notifyListeners();

    if (context != null && context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  Future<void> _clearSession() async {
    try {
      if (_token != null && _refreshToken != null) {
        await apiService.post(
          '/users/logout/',
          body: {'refresh': _refreshToken},
        );
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_state');
    await prefs.remove('user_city');

    final userId = _userId;
    if (userId != null) {
      await prefs.remove('profilePhotoUrl_$userId');
    }

    _token = null;
    _refreshToken = null;
    _userId = null;
    _userEmail = null;
    _userData = null;
  }

  Future<void> refreshUserProfile() async {
    if (_token == null) return;

    try {
      final result = await apiService.get('/users/me/');
      if (result.success && result.data != null) {
        final data = result.data!;
        _userData = data.containsKey('data') ? data['data'] as Map<String, dynamic>? : data;
        notifyListeners();
      }
    } catch (_) {}
  }
}