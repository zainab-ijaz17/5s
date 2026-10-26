import '../data/gemba_demo_data.dart';
import '../models/gemba_employee.dart';
import '../models/gemba_user.dart';
import 'api_service.dart';
import 'gemba_session_service.dart';

class GembaAuthService {
  Future<GembaUser> sfLogin({
    required String username,
    required String password,
  }) async {
    final response = await ApiService.post(
      '/gemba/auth/sf-login',
      {
        'username': username.trim(),
        'password': password,
      },
      auth: false,
    );

    final map = Map<String, dynamic>.from(response as Map);
    final token = map['accessToken']?.toString() ?? '';
    final userMap = Map<String, dynamic>.from(map['user'] as Map? ?? {});
    final user = GembaUser.fromJson(userMap);

    if (token.isEmpty) {
      throw Exception('Login succeeded but no access token was returned');
    }

    await GembaSessionService.instance.saveSession(
      user: user,
      accessToken: token,
    );
    return user;
  }

  Future<List<GembaEmployee>> listEmployees({
    required String bu,
  }) async {
    final session = await GembaSessionService.instance.loadSession();
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Not signed in to Digital Gemba');
    }

    final response = await ApiService.get(
      '/gemba/auth/employees',
      accessToken: token,
      queryParameters: {'bu': bu},
    );

    // Accept either a raw list or { data: [...] } / { employees: [...] }.
    List<dynamic> list;
    if (response is List) {
      list = response;
    } else if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final nested = map['data'] ?? map['employees'] ?? map['results'];
      list = nested is List ? nested : const [];
    } else {
      list = const [];
    }

    final employees = list
        .whereType<Map>()
        .map((row) => GembaEmployee.fromJson(Map<String, dynamic>.from(row)))
        .where((e) => e.employeeNumber.isNotEmpty)
        .toList();

    return GembaDemoData.withDemoEmployee(employees);
  }

  Future<void> signOut() async {
    await GembaSessionService.instance.clearSession();
  }
}
