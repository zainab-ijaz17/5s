import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'api_service.dart';
import 'auth_service.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const String _userKey = 'session_user_v1';
  static const String _auditorKey = 'session_auditor_v1';
  static const String _auditeeKey = 'session_auditee_v1';
  static const String _routeKey = 'session_last_route_v1';
  static const String _companyKey = 'session_company_v1';
  static const String _buKey = 'session_bu_v1';
  static const String _sectionKey = 'session_section_v1';

  final AuthService _auth = AuthService();

  Future<void> saveSession({
    required User user,
    required String accessToken,
    String? refreshToken,
    String? auditor,
    String? auditee,
    String? lastRoute,
    String? company,
    String? bu,
    String? section,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await ApiService.setAccessToken(accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await ApiService.setRefreshToken(refreshToken);
    }
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await _writeOptional(prefs, _auditorKey, auditor);
    await _writeOptional(prefs, _auditeeKey, auditee);
    await _writeOptional(prefs, _routeKey, lastRoute);
    await _writeOptional(prefs, _companyKey, company);
    await _writeOptional(prefs, _buKey, bu);
    await _writeOptional(prefs, _sectionKey, section);
  }

  Future<void> saveAssessmentContext({
    String? auditor,
    String? auditee,
    String? company,
    String? bu,
    String? section,
    String? lastRoute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _writeOptional(prefs, _auditorKey, auditor);
    await _writeOptional(prefs, _auditeeKey, auditee);
    await _writeOptional(prefs, _companyKey, company);
    await _writeOptional(prefs, _buKey, bu);
    await _writeOptional(prefs, _sectionKey, section);
    await _writeOptional(prefs, _routeKey, lastRoute);
  }

  Future<void> _writeOptional(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
      return;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, trimmed);
  }

  Future<StoredSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userRaw = prefs.getString(_userKey);
    if (userRaw == null || userRaw.isEmpty) return null;

    try {
      final user = User.fromJson(
        Map<String, dynamic>.from(jsonDecode(userRaw) as Map),
      );
      final token = await ApiService.getAccessToken();
      if (token == null || token.isEmpty) return null;

      return StoredSession(
        user: user,
        auditor: prefs.getString(_auditorKey),
        auditee: prefs.getString(_auditeeKey),
        lastRoute: prefs.getString(_routeKey),
        company: prefs.getString(_companyKey),
        bu: prefs.getString(_buKey),
        section: prefs.getString(_sectionKey),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> restoreAndRefreshToken() async {
    final session = await loadSession();
    if (session == null) return false;

    try {
      await _auth.ensureValidAccessToken();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await ApiService.clearTokens();
    await prefs.remove(_userKey);
    await prefs.remove(_auditorKey);
    await prefs.remove(_auditeeKey);
    await prefs.remove(_routeKey);
    await prefs.remove(_companyKey);
    await prefs.remove(_buKey);
    await prefs.remove(_sectionKey);
  }
}

class StoredSession {
  final User user;
  final String? auditor;
  final String? auditee;
  final String? lastRoute;
  final String? company;
  final String? bu;
  final String? section;

  StoredSession({
    required this.user,
    this.auditor,
    this.auditee,
    this.lastRoute,
    this.company,
    this.bu,
    this.section,
  });
}
