import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/submitted_assessment.dart';

class AppState extends ChangeNotifier {
  static const String _assessmentsStorageKey = 'submitted_assessments_v1';

  User? currentUser;
  String? auditorName;
  String? auditeeName;
  String? selectedCompany;
  String? selectedBU;
  String? selectedSection;

  String? powerUserSelectedBU;
  String? powerUserSelectedSection;

  final List<SubmittedAssessment> assessments = [];
  final Set<String> flaggedBUs = {};

  bool isInitialized = false;

  String get _normalizedRole => (currentUser?.role ?? '').toLowerCase();

  bool get isAdmin => _normalizedRole == 'admin';

  bool get isPowerUser =>
      _normalizedRole == 'poweruser' || _normalizedRole == 'power_user';

  bool get isBUManager =>
      _normalizedRole == 'bumanager' ||
      _normalizedRole == 'bu_manager' ||
      _normalizedRole == 'manager';

  // ==============================
  // INITIALIZATION
  // ==============================

  Future<void> loadInitial() async {
    try {
      await _loadAssessmentsFromDisk();
      isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error during app initialization: $e');
      // Set as initialized even if loading fails to prevent infinite loading
      isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadAssessmentsFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_assessmentsStorageKey);

      if (raw == null || raw.isEmpty) {
        debugPrint('No assessment data found in storage');
        return;
      }

      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        debugPrint('Stored data is not a List');
        return;
      }

      assessments
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .map((json) {
            try {
              return SubmittedAssessment.fromJson(json);
            } catch (e) {
              debugPrint('Skipping corrupted assessment: $e');
              return null;
            }
          }).whereType<SubmittedAssessment>(),
        );

      _updateFlaggedBUs();

      debugPrint('Loaded ${assessments.length} assessments from disk');
    } catch (e) {
      debugPrint('Error loading assessments: $e');
    }
  }

  // ==============================
  // SAVE
  // ==============================

  Future<void> _saveAssessmentsToDisk() async {
    try {
      if (!isInitialized) {
        debugPrint('Skipping save — state not initialized yet');
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      final raw = jsonEncode(
        assessments.map((a) => a.toJson()).toList(),
      );

      await prefs.setString(_assessmentsStorageKey, raw);

      debugPrint('Saved ${assessments.length} assessments to disk');
    } catch (e) {
      debugPrint('Error saving assessments: $e');
    }
  }

  // ==============================
  // FLAGGED BU MANAGEMENT
  // ==============================

  void _updateFlaggedBUs() {
    flaggedBUs.clear();
    for (final sa in assessments) {
      if (sa.isFlagged && !sa.resolved && sa.bu != null) {
        flaggedBUs.add(sa.bu!);
      }
    }
  }

  // ==============================
  // USER + SELECTIONS
  // ==============================

  void setLogin(User user, {String? auditor, String? auditee}) {
    currentUser = user;
    auditorName = auditor ?? auditorName;
    auditeeName = auditee ?? auditeeName;
    notifyListeners();
  }

  void selectCompany(String company) {
    selectedCompany = company;
    notifyListeners();
  }

  void selectBU(String bu) {
    selectedBU = bu;
    notifyListeners();
  }

  void selectSection(String? section) {
    selectedSection = section;
    notifyListeners();
  }

  void selectPowerUserBU(String bu) {
    powerUserSelectedBU = bu;
    notifyListeners();
  }

  void selectPowerUserSection(String section) {
    powerUserSelectedSection = section;
    notifyListeners();
  }

  // ==============================
  // CRUD OPERATIONS
  // ==============================

  void addSubmittedAssessment(SubmittedAssessment sa) {
    assessments.add(sa);
    _updateFlaggedBUs();
    notifyListeners();
    _saveAssessmentsToDisk();
  }

  void updateSubmittedAssessment(SubmittedAssessment updated) {
    final idx = assessments.indexWhere((a) => a.id == updated.id);

    if (idx != -1) {
      assessments[idx] = updated;
      _updateFlaggedBUs();
      notifyListeners();
      _saveAssessmentsToDisk();
    }
  }

  void resolveAssessment(String id, {String? resolvedBy}) {
    final idx = assessments.indexWhere((a) => a.id == id);

    if (idx != -1) {
      final existing = assessments[idx];

      assessments[idx] = SubmittedAssessment(
        id: existing.id,
        company: existing.company,
        auditorName: existing.auditorName,
        auditeeName: existing.auditeeName,
        date: existing.date,
        items: existing.items,
        score: existing.score,
        isFlagged: false,
        bu: existing.bu,
        section: existing.section,
        followUpDueAt: existing.followUpDueAt,
        followUpSent: existing.followUpSent,
        resolved: true,
        resolvedAt: DateTime.now(),
        resolvedBy: resolvedBy ?? currentUser?.name,
      );

      _updateFlaggedBUs();
      notifyListeners();
      _saveAssessmentsToDisk();
    }
  }

  // ==============================
  // FOLLOW-UP SWEEP
  // ==============================

  Future<void> sweepFollowUps(dynamic emailService) async {
    final now = DateTime.now();
    bool modified = false;

    for (var i = 0; i < assessments.length; i++) {
      final sa = assessments[i];

      if (sa.isFlagged &&
          sa.followUpDueAt != null &&
          sa.followUpDueAt!.isBefore(now) &&
          !sa.followUpSent) {
        await emailService.sendFollowUpEmail(sa);

        assessments[i] = SubmittedAssessment(
          id: sa.id,
          company: sa.company,
          auditorName: sa.auditorName,
          auditeeName: sa.auditeeName,
          date: sa.date,
          items: sa.items,
          score: sa.score,
          isFlagged: sa.isFlagged,
          bu: sa.bu,
          section: sa.section,
          followUpDueAt: sa.followUpDueAt,
          followUpSent: true,
          resolved: sa.resolved,
          resolvedAt: sa.resolvedAt,
          resolvedBy: sa.resolvedBy,
        );

        modified = true;
      }
    }

    if (modified) {
      notifyListeners();
      await _saveAssessmentsToDisk();
    }
  }
}
