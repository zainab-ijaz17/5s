import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/gemba_user.dart';

class GembaSession {
  final GembaUser user;
  final String accessToken;

  const GembaSession({
    required this.user,
    required this.accessToken,
  });
}

class GembaSessionService {
  GembaSessionService._();
  static final GembaSessionService instance = GembaSessionService._();

  static const _userKey = 'gemba_user_json';
  static const _tokenKey = 'gemba_access_token';

  Future<void> saveSession({
    required GembaUser user,
    required String accessToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await prefs.setString(_tokenKey, accessToken);
  }

  Future<GembaSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userRaw = prefs.getString(_userKey);
    final token = prefs.getString(_tokenKey);
    if (userRaw == null || userRaw.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    try {
      final map = jsonDecode(userRaw) as Map<String, dynamic>;
      return GembaSession(
        user: GembaUser.fromJson(map),
        accessToken: token,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
  }
}
