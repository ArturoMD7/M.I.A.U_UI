import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
  });

  factory ApiResponse.success(T data) {
    return ApiResponse(success: true, data: data);
  }

  factory ApiResponse.error(String message) {
    return ApiResponse(success: false, message: message);
  }

  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    bool isList = false,
  }) {
    if (json.containsKey('error') && json['error'] != null) {
      final errorData = json['error'];
      String message = 'Error desconocido';
      if (errorData is Map) {
        message = errorData['message'] ?? errorData.toString();
      } else if (errorData is String) {
        message = errorData;
      }
      return ApiResponse<T>.error(message);
    }

    if (json.containsKey('data')) {
      return ApiResponse<T>.success(json['data'] as T);
    }

    if (isList) {
      return ApiResponse<T>.success(json as T);
    }

    return ApiResponse<T>.success(json as T);
  }
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String get baseUrl => dotenv.env['API_URL'] ?? 'http://localhost:8765/api';
  String get mediaUrl => dotenv.env['MEDIA_URL'] ?? 'http://localhost:8765';
  String get zipCodeApiUrl =>
      dotenv.env['ZIP_CODE_API_URL'] ?? 'https://mexico-api.devaleff.com/api';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Map<String, String> getHeaders({bool requiresAuth = true, String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth && token != null) {
      headers['Authorization'] = 'Bearer $token';
    } else if (requiresAuth) {
      getToken().then((token) {
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
      });
    }

    return headers;
  }

  Future<ApiResponse<Map<String, dynamic>>> get(
    String endpoint, {
    bool requiresAuth = true,
    Map<String, String>? queryParams,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;

      String url = '$baseUrl$endpoint';
      if (queryParams != null && queryParams.isNotEmpty) {
        final uri = Uri.parse(url).replace(queryParameters: queryParams);
        url = uri.toString();
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: getHeaders(requiresAuth: requiresAuth, token: token),
          )
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    } on TimeoutException {
      return ApiResponse.error('Tiempo de espera agotado');
    } catch (e) {
      return ApiResponse.error('Error de conexión: ${e.toString()}');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;

      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: getHeaders(requiresAuth: requiresAuth, token: token),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    } on TimeoutException {
      return ApiResponse.error('Tiempo de espera agotado');
    } catch (e) {
      return ApiResponse.error('Error de conexión: ${e.toString()}');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;

      final response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: getHeaders(requiresAuth: requiresAuth, token: token),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    } on TimeoutException {
      return ApiResponse.error('Tiempo de espera agotado');
    } catch (e) {
      return ApiResponse.error('Error de conexión: ${e.toString()}');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;

      final response = await http
          .delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: getHeaders(requiresAuth: requiresAuth, token: token),
          )
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    } on TimeoutException {
      return ApiResponse.error('Tiempo de espera agotado');
    } catch (e) {
      return ApiResponse.error('Error de conexión: ${e.toString()}');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> multipartPut(
    String endpoint, {
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
    bool requiresAuth = true,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl$endpoint'),
      );
      request.headers.addAll(
        getHeaders(requiresAuth: requiresAuth, token: token),
      );

      if (fields != null) {
        request.fields.addAll(fields);
      }

      if (files != null) {
        request.files.addAll(files);
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on TimeoutException {
      return ApiResponse.error('Tiempo de espera agotado');
    } catch (e) {
      return ApiResponse.error('Error de conexión: ${e.toString()}');
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> multipartPost(
    String endpoint, {
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
    bool requiresAuth = true,
  }) async {
    try {
      final token = requiresAuth ? await getToken() : null;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$endpoint'),
      );
      request.headers.addAll(
        getHeaders(requiresAuth: requiresAuth, token: token),
      );

      if (fields != null) {
        request.fields.addAll(fields);
      }

      if (files != null) {
        request.files.addAll(files);
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } on TimeoutException {
      return ApiResponse.error('Tiempo de espera agotado');
    } catch (e) {
      return ApiResponse.error('Error de conexión: ${e.toString()}');
    }
  }

  ApiResponse<Map<String, dynamic>> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        final result = ApiResponse<Map<String, dynamic>>.success({});
        result.statusCode = response.statusCode;
        return result;
      }

      try {
        final json = jsonDecode(response.body);
        if (json is List) {
          final result = ApiResponse<Map<String, dynamic>>.success({
            'data': json,
          });
          result.statusCode = response.statusCode;
          return result;
        }
        final result = ApiResponse<Map<String, dynamic>>.fromJson(json);
        result.statusCode = response.statusCode;
        return result;
      } catch (e) {
        final result = ApiResponse<Map<String, dynamic>>.success({});
        result.statusCode = response.statusCode;
        return result;
      }
    }

    String errorMessage = 'Error ${response.statusCode}';
    debugPrint("Error response body: ${response.body}");
    try {
      final json = jsonDecode(response.body);
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(json);
      if (apiResponse.message != null) {
        errorMessage = apiResponse.message!;
      }
    } catch (e) {
      errorMessage = 'Error del servidor: ${response.statusCode}';
    }

    final errorResult = ApiResponse<Map<String, dynamic>>.error(errorMessage);
    errorResult.statusCode = response.statusCode;
    return errorResult;
  }

  String getFullMediaUrl(String? relativeUrl) {
    if (relativeUrl == null || relativeUrl.isEmpty) {
      return '';
    }

    if (relativeUrl.startsWith('http')) {
      return relativeUrl;
    }

    return '$mediaUrl${relativeUrl.startsWith('/') ? relativeUrl : '/$relativeUrl'}';
  }
}

final apiService = ApiService();
