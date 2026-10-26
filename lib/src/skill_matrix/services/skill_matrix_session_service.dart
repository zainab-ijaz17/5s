import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/skill_matrix_role.dart';
import '../models/skill_matrix_user_profile.dart';

class SkillMatrixSessionService {
  SkillMatrixSessionService._();
  static final SkillMatrixSessionService instance = SkillMatrixSessionService._();

  static const _roleKey = 'skill_matrix_role';
  static const _tokenKey = 'skill_matrix_access_token';
  static const _profileKey = 'skill_matrix_profile';

  String? _cachedToken;
  SkillMatrixUserProfile? _cachedProfile;

  Future<String?> get accessToken async {
    _cachedToken ??= (await SharedPreferences.getInstance()).getString(_tokenKey);
    return _cachedToken;
  }

  Future<SkillMatrixUserProfile?> get profile async {
    if (_cachedProfile != null) return _cachedProfile;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      _cachedProfile = SkillMatrixUserProfile.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      return _cachedProfile;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession({
    required String accessToken,
    required SkillMatrixUserProfile profile,
  }) async {
    final role = SkillMatrixRole.fromApiName(profile.roleName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_profileKey, jsonEncode(_profileToJson(profile)));
    if (role != null) {
      await prefs.setString(_roleKey, role.name);
    }
    _cachedToken = accessToken;
    _cachedProfile = profile;
  }

  Future<void> saveRole(SkillMatrixRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role.name);
  }

  Future<SkillMatrixRole?> loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_roleKey);
    if (raw == null || raw.isEmpty) return null;
    for (final role in SkillMatrixRole.values) {
      if (role.name == raw) return role;
    }
    return null;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_profileKey);
    _cachedToken = null;
    _cachedProfile = null;
  }

  Future<void> clearRole() => clearSession();

  Map<String, dynamic> _profileToJson(SkillMatrixUserProfile p) => {
        'id': p.id,
        'fullName': p.fullName,
        'email': p.email,
        'employeeNumber': p.employeeNumber,
        'department': p.department,
        'areaLine': p.areaLine,
        'designation': p.designation,
        'photoUrl': p.photoUrl,
        'dateOfJoining': p.dateOfJoining,
        'role': {'name': p.roleName},
        if (p.levelCode != null) 'level': {'code': p.levelCode},
        if (p.categoryName != null) 'category': {'name': p.categoryName},
        if (p.lineManagerName != null)
          'lineManager': {'fullName': p.lineManagerName},
      };
}
