import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException: $statusCode $message';
}

class ApiClient {
  static const _storage = FlutterSecureStorage();

  // Use http for emulator, but --dart-define=ALLOW_INSECURE_HTTP=true can be passed.
  // The default in production is https.
  static String get baseUrl {
    const allowInsecure = bool.fromEnvironment('ALLOW_INSECURE_HTTP', defaultValue: false);
    if (!allowInsecure) {
      // In production, we require https://
      return 'https://localhost:8080/api/v1'; // Replace with real production url if needed.
    }
    // Fallback for emulator testing:
    return Platform.isAndroid ? 'http://10.0.2.2:8080/api/v1' : 'http://localhost:8080/api/v1';
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: 'jwt_token');
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> _processResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await clearToken();
    }

    String message = 'Request failed';
    try {
      final body = jsonDecode(response.body);
      message = body['message'] ?? message;
    } catch (_) {}

    throw ApiException(response.statusCode, message);
  }

  static Future<dynamic> get(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.get(uri, headers: await _getHeaders()).timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }

  static Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await http.post(
      uri,
      headers: await _getHeaders(),
      body: body != null ? jsonEncode(body) : null,
    ).timeout(const Duration(seconds: 15));
    return _processResponse(response);
  }
}
