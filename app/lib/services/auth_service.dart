import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthUser {
  AuthUser({
    required this.driverId,
    required this.name,
  });

  final String driverId;
  final String name;
}

class AuthService {
  static const _keyDriverId = 'driver_id';
  static const _keyDriverName = 'driver_name';

  Future<AuthUser?> login(String username, String password) async {
    try {
      final response = await ApiClient.post('/auth/login', body: {
        'username': username,
        'password': password,
      });

      final token = response['token'];
      final userJson = response['user'];

      await ApiClient.saveToken(token);

      final user = AuthUser(
        driverId: userJson['id'].toString(),
        name: userJson['fullName'] ?? username,
      );
      await saveSession(user);
      return user;
    } on ApiException catch (e) {
      throw Exception('Login failed: ${e.message}');
    } catch (e) {
      throw Exception('Could not connect to server. Is the backend running?');
    }
  }

  Future<void> saveSession(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDriverId, user.driverId);
    await prefs.setString(_keyDriverName, user.name);
  }

  Future<AuthUser?> currentUser() async {
    final token = await ApiClient.getToken();
    if (token == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getString(_keyDriverId);
    final name = prefs.getString(_keyDriverName);

    if (driverId == null || name == null || driverId.isEmpty) {
      return null;
    }

    // Optionally fetch /users/me to refresh profile
    return AuthUser(driverId: driverId, name: name);
  }

  Future<void> logout() async {
    await ApiClient.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDriverId);
    await prefs.remove(_keyDriverName);
  }
}
