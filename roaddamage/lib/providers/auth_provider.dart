import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userId;
  String? _fullname;
  String? _email;
  String? _role;
  final ApiService _apiService = ApiService();

  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get fullname => _fullname;
  String? get email => _email;
  String? get role => _role;

  Future<bool> login(String email, String password) async {
    try {
      print('Attempting login with email: $email');
      final response = await _apiService.login(email, password);
      print('Login response received: $response');

      _userId = response['userId'];
      _fullname = response['fullname'];
      _email = response['email'];
      _role = response['role'];
      _isAuthenticated = true;

      print('User authenticated: $_fullname ($_email)');

      // Save login state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAuthenticated', true);
      await prefs.setString('userId', _userId!);
      await prefs.setString('fullname', _fullname!);
      await prefs.setString('email', _email!);
      await prefs.setString('role', _role!);

      notifyListeners();
      return true;
    } catch (e) {
      print('Login failed: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _userId = null;
    _fullname = null;
    _email = null;
    _role = null;

    // Clear saved login state
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isAuthenticated');
    await prefs.remove('userId');
    await prefs.remove('fullname');
    await prefs.remove('email');
    await prefs.remove('role');

    notifyListeners();
  }

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    if (_isAuthenticated) {
      _userId = prefs.getString('userId');
      _fullname = prefs.getString('fullname');
      _email = prefs.getString('email');
      _role = prefs.getString('role');
    }
    notifyListeners();
  }
}
