import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class DriverProfile {
  DriverProfile({
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.emergencyContact,
  });

  final String name;
  final String phone;
  final String email;
  final String address;
  final String emergencyContact;

  static const sampleVehicle = 'Company Vehicle';
}

class ProfileService {
  static const _keyName = 'profile_name';
  static const _keyPhone = 'profile_phone';
  static const _keyEmail = 'profile_email';
  static const _keyAddress = 'profile_address';
  static const _keyEmergency = 'profile_emergency';

  Future<DriverProfile> load(String fallbackName) async {
    final prefs = await SharedPreferences.getInstance();

    String backendName = fallbackName;
    try {
      final json = await ApiClient.get('/users/me');
      if (json != null && json['fullName'] != null) {
        backendName = json['fullName'];
      }
    } catch (_) {}

    return DriverProfile(
      name: prefs.getString(_keyName) ?? backendName,
      phone: prefs.getString(_keyPhone) ?? '',
      email: prefs.getString(_keyEmail) ?? '',
      address: prefs.getString(_keyAddress) ?? '',
      emergencyContact: prefs.getString(_keyEmergency) ?? '',
    );
  }

  Future<void> save(DriverProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, profile.name);
    await prefs.setString(_keyPhone, profile.phone);
    await prefs.setString(_keyEmail, profile.email);
    await prefs.setString(_keyAddress, profile.address);
    await prefs.setString(_keyEmergency, profile.emergencyContact);
  }
}
