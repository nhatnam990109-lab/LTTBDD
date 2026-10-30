import 'package:cliniccare/api.dart';
import 'package:cliniccare/format.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSession extends ChangeNotifier {
  AppSession({ClinicApi? api}) : api = api ?? ClinicApi();

  final ClinicApi api;
  Map<String, dynamic>? user;
  Map<String, dynamic>? meta;
  String? bootError;
  bool ready = false;

  List<Map<String, dynamic>> get packages => asList(meta?['packages']);
  List<Map<String, dynamic>> get branches => asList(meta?['branches']);
  List<Map<String, dynamic>> get doctors => asList(meta?['doctors']);

  bool get isAdmin => user?['role'] == 'admin';
  bool get isDoctor => user?['role'] == 'doctor';
  bool get isStaff => isAdmin || isDoctor;

  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    api.token = prefs.getString('cliniccare_token');
    try {
      meta = await api.get('/api/meta');
      bootError = null;
      if (api.token != null) {
        try {
          final me = await api.get('/api/me');
          user = asMap(me['user']);
        } on ApiException {
          await _clearToken();
        }
      }
    } on ApiException catch (error) {
      bootError = error.message;
    }
    ready = true;
    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await api.post('/api/auth/login', {'email': email.trim(), 'password': password});
    api.token = '${result['token']}';
    user = asMap(result['user']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cliniccare_token', api.token!);
    notifyListeners();
    return user!;
  }

  Future<void> logout() async {
    try {
      if (api.token != null) await api.post('/api/auth/logout');
    } catch (_) {}
    await _clearToken();
    notifyListeners();
  }

  Future<void> refreshUser(Map<String, dynamic> next) async {
    user = next;
    notifyListeners();
  }

  Future<void> _clearToken() async {
    api.token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cliniccare_token');
  }

  Map<String, dynamic>? packageById(String? id) {
    for (final item in packages) {
      if (item['id'] == id) return item;
    }
    return null;
  }

  Map<String, dynamic>? doctorById(String? id) {
    for (final item in doctors) {
      if (item['id'] == id) return item;
    }
    return null;
  }
}

final session = AppSession();
