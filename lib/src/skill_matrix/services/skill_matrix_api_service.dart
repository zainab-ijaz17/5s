import '../../services/api_service.dart';
import '../models/skill_matrix_models.dart';
import '../models/skill_matrix_user_profile.dart';
import 'skill_matrix_session_service.dart';

class SkillMatrixApiService {
  SkillMatrixApiService._();
  static final SkillMatrixApiService instance = SkillMatrixApiService._();

  Future<String> _token() async {
    final t = await SkillMatrixSessionService.instance.accessToken;
    if (t == null || t.isEmpty) {
      throw Exception('Not signed in to Skill Matrix');
    }
    return t;
  }

  Future<SkillMatrixUserProfile> login({
    required String employeeNumber,
    required String password,
  }) async {
    final response = await ApiService.post(
      '/skill-matrix/auth/login',
      {
        'employeeNumber': employeeNumber.trim(),
        'password': password,
      },
      auth: false,
    );
    final map = Map<String, dynamic>.from(response as Map);
    final token = map['accessToken']?.toString() ?? '';
    final user = SkillMatrixUserProfile.fromJson(
      Map<String, dynamic>.from(map['user'] as Map? ?? {}),
    );
    if (token.isEmpty) {
      throw Exception('Login failed: no token');
    }
    await SkillMatrixSessionService.instance.saveSession(
      accessToken: token,
      profile: user,
    );
    return user;
  }

  Future<SkillMatrixUserProfile> fetchMe() async {
    final response = await ApiService.get(
      '/skill-matrix/me',
      accessToken: await _token(),
    );
    return SkillMatrixUserProfile.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<Map<String, dynamic>> currentAssessment() async {
    final response = await ApiService.get(
      '/skill-matrix/assessments/current',
      accessToken: await _token(),
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<List<SkillMatrixSkillRow>> fetchCurrentLines() async {
    final data = await currentAssessment();
    return _linesFromJson(data['lines']);
  }

  Future<List<Map<String, dynamic>>> fetchSkillsForMe() async {
    final response = await ApiService.get(
      '/skill-matrix/skills/for-me',
      accessToken: await _token(),
    );
    if (response is! List) return [];
    return response.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMasterCategories() async {
    final response = await ApiService.get(
      '/skill-matrix/master/categories',
      accessToken: await _token(),
    );
    if (response is! List) return [];
    return response.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchMasterLevels() async {
    final response = await ApiService.get(
      '/skill-matrix/master/levels',
      accessToken: await _token(),
    );
    if (response is! List) return [];
    return response.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> createSkill({
    required String name,
    required String categoryId,
    String? department,
    String? area,
    String? description,
    required List<String> applicableLevelIds,
    required int defaultRequiredLevel,
  }) async {
    await ApiService.post(
      '/skill-matrix/admin/skills',
      {
        'name': name,
        'categoryId': categoryId,
        if (department != null && department.isNotEmpty) 'department': department,
        if (area != null && area.isNotEmpty) 'area': area,
        if (description != null && description.isNotEmpty) 'description': description,
        'applicableLevelIds': applicableLevelIds,
        'defaultRequiredLevel': defaultRequiredLevel,
      },
      accessToken: await _token(),
    );
  }

  Future<List<String>> fetchCategories() async {
    final response = await ApiService.get(
      '/skill-matrix/master/categories',
      accessToken: await _token(),
    );
    if (response is! List) return [];
    return response
        .map((e) => (e as Map)['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> upsertSelfLine({
    required String skillId,
    required int selfRating,
    String? selfComment,
  }) async {
    await ApiService.post(
      '/skill-matrix/assessments/lines',
      {
        'skillId': skillId,
        'selfRating': selfRating,
        if (selfComment != null && selfComment.isNotEmpty)
          'selfComment': selfComment,
      },
      accessToken: await _token(),
    );
  }

  Future<void> submitAssessment() async {
    await ApiService.post(
      '/skill-matrix/assessments/submit',
      {},
      accessToken: await _token(),
    );
  }

  /// Saves the worker assessment for line manager review (same as submit).
  Future<void> saveAssessmentForReview() => submitAssessment();

  Future<List<SkillMatrixEmployeeSummary>> fetchManagerTeam() async {
    final response = await ApiService.get(
      '/skill-matrix/manager/team',
      accessToken: await _token(),
    );
    if (response is! List) return [];
    return response.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return SkillMatrixEmployeeSummary(
        id: m['id']?.toString() ?? '',
        userId: m['userId']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        department: m['department']?.toString() ?? '',
        level: m['level']?.toString() ?? '',
        assessmentStatus: m['assessmentStatus']?.toString() ?? '',
        overallScore: (m['overallScore'] as num?)?.toDouble(),
        openGaps: (m['openGaps'] as num?)?.toInt() ?? 0,
        awaitingReview: m['awaitingReview'] == true,
      );
    }).toList();
  }

  Future<ManagerAssessmentView> fetchManagerAssessment(String workerUserId) async {
    final response = await ApiService.get(
      '/skill-matrix/manager/assessments/$workerUserId',
      accessToken: await _token(),
    );
    final map = Map<String, dynamic>.from(response as Map);
    return ManagerAssessmentView(
      assessmentId: map['assessmentId']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      cycleLabel: map['cycleLabel']?.toString() ?? '',
      lines: _linesFromJson(map['lines']),
    );
  }

  Future<void> saveManagerLines({
    required String assessmentId,
    required List<Map<String, dynamic>> lines,
  }) async {
    await ApiService.patch(
      '/skill-matrix/manager/assessments/$assessmentId/lines',
      {'lines': lines},
      accessToken: await _token(),
    );
  }

  Future<void> approveAssessment(String assessmentId) async {
    await ApiService.post(
      '/skill-matrix/manager/assessments/$assessmentId/approve',
      {},
      accessToken: await _token(),
    );
  }

  Future<List<SkillMatrixGapItem>> fetchMyGaps() async {
    final response = await ApiService.get(
      '/skill-matrix/gaps/mine',
      accessToken: await _token(),
    );
    if (response is! List) return [];
    return response.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return SkillMatrixGapItem(
        category: m['category']?.toString() ?? '',
        skill: m['skill']?.toString() ?? '',
        current: (m['current'] as num?)?.toInt() ?? 0,
        required: (m['required'] as num?)?.toInt() ?? 0,
        assignedTraining: m['assignedTraining']?.toString(),
      );
    }).toList();
  }

  Future<List<SkillMatrixTrainingItem>> fetchMyTrainings() async {
    final response = await ApiService.get(
      '/skill-matrix/trainings/mine',
      accessToken: await _token(),
    );
    if (response is! List) return [];
    return response.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return SkillMatrixTrainingItem(
        id: m['id']?.toString(),
        skillId: m['skillId']?.toString(),
        requiredLevel: (m['requiredLevel'] as num?)?.toInt(),
        title: m['title']?.toString() ?? '',
        category: m['category']?.toString() ?? '',
        linkedGap: m['linkedGap']?.toString() ?? '',
        assignedBy: m['assignedBy']?.toString() ?? '',
        assignedByRole: m['assignedByRole']?.toString() ?? '',
        dueDate: m['dueDate']?.toString() ?? '',
        status: m['status']?.toString() ?? '',
        hours: m['hours']?.toString() ?? '',
        requiresSelfAssessment: m['requiresSelfAssessment'] == true,
        canRateForTraining: m['canRateForTraining'] == true,
        selfAssessmentPending: m['selfAssessmentPending'] == true,
      );
    }).toList();
  }

  Future<List<SkillMatrixUserProfile>> fetchAdminUsers() async {
    final response = await ApiService.get(
      '/skill-matrix/admin/users',
      accessToken: await _token(),
    );
    if (response is! List) return [];
    return response
        .map(
          (e) => SkillMatrixUserProfile.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<SkillMatrixAdminSkill>> fetchAdminSkills() async {
    final response = await ApiService.get(
      '/skill-matrix/admin/skills',
      accessToken: await _token(),
    );
    if (response is! List) return [];
    return response.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final cat = m['category'];
      final applicable = (m['applicableLevels'] as List?) ?? [];
      final reqs = (m['requirements'] as List?) ?? [];
      return SkillMatrixAdminSkill(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        categoryName: cat is Map ? cat['name']?.toString() ?? '' : '',
        department: m['department']?.toString(),
        area: m['area']?.toString(),
        description: m['description']?.toString(),
        applicableLevels: applicable
            .map((a) {
              final level = (a as Map)['level'];
              return level is Map ? level['code']?.toString() ?? '' : '';
            })
            .where((s) => s.isNotEmpty)
            .toList(),
        requirements: {
          for (final r in reqs)
            if (r is Map && r['level'] is Map)
              (r['level'] as Map)['code']?.toString() ?? '':
                  (r['requiredLevel'] as num?)?.toInt() ?? 0,
        },
      );
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchTrainingCatalog() async {
    final response = await ApiService.get(
      '/skill-matrix/admin/trainings',
      accessToken: await _token(),
    );
    if (response is! List) return [];
    return response.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> createTraining({
    required String name,
    String? description,
    double? durationHours,
  }) async {
    await ApiService.post(
      '/skill-matrix/admin/trainings',
      {
        'name': name,
        if (description != null) 'description': description,
        if (durationHours != null) 'durationHours': durationHours,
      },
      accessToken: await _token(),
    );
  }

  Future<void> assignTrainingToWorker({
    required String workerId,
    required String trainingId,
    String? skillId,
    String? dueDate,
  }) async {
    await ApiService.post(
      '/skill-matrix/admin/training-assignments',
      {
        'workerId': workerId,
        'trainingId': trainingId,
        if (skillId != null) 'skillId': skillId,
        if (dueDate != null) 'dueDate': dueDate,
      },
      accessToken: await _token(),
    );
  }

  Future<ManagerAssessmentView> fetchValidatedForWorker() async {
    final response = await ApiService.get(
      '/skill-matrix/worker/validated-assessment',
      accessToken: await _token(),
    );
    final map = Map<String, dynamic>.from(response as Map);
    return ManagerAssessmentView(
      assessmentId: '',
      status: map['status']?.toString() ?? '',
      cycleLabel: map['cycleLabel']?.toString() ?? '',
      lines: _linesFromJson(map['lines']),
      showManagerView: map['showManagerView'] == true,
    );
  }

  List<SkillMatrixSkillRow> _linesFromJson(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((item) {
      final m = Map<String, dynamic>.from(item as Map);
      return SkillMatrixSkillRow(
        id: m['id']?.toString() ?? '',
        skillId: m['skillId']?.toString(),
        category: m['category']?.toString() ?? '',
        skill: m['skill']?.toString() ?? '',
        requiredLevel: _optionalInt(m['requiredLevel']) ?? 0,
        selfRating: _optionalInt(m['selfRating']),
        managerRating: _optionalInt(m['managerRating']),
        workerComment: m['selfComment']?.toString(),
        managerComment: m['managerComment']?.toString(),
      );
    }).toList();
  }

  int? _optionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

class SkillMatrixAdminSkill {
  const SkillMatrixAdminSkill({
    required this.id,
    required this.name,
    required this.categoryName,
    this.department,
    this.area,
    this.description,
    required this.applicableLevels,
    required this.requirements,
  });

  final String id;
  final String name;
  final String categoryName;
  final String? department;
  final String? area;
  final String? description;
  final List<String> applicableLevels;
  final Map<String, int> requirements;
}

class ManagerAssessmentView {
  const ManagerAssessmentView({
    required this.assessmentId,
    required this.status,
    required this.cycleLabel,
    required this.lines,
    this.showManagerView = false,
  });

  final String assessmentId;
  final String status;
  final String cycleLabel;
  final List<SkillMatrixSkillRow> lines;
  final bool showManagerView;
}
