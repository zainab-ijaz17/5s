import 'dart:async';
import '../models/submitted_assessment.dart';
import 'api_service.dart';

class AssessmentService {
  // Singleton pattern
  static final AssessmentService _instance = AssessmentService._internal();
  factory AssessmentService() => _instance;
  AssessmentService._internal();

  Future<List<SubmittedAssessment>> getAllAssessments() async {
    final response = await ApiService.get('/assessments');
    final list = response is List ? response : <dynamic>[];
    return list
        .whereType<Map>()
        .map((m) => SubmittedAssessment.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<SubmittedAssessment?> getAssessmentById(String id) async {
    if (id.isEmpty) return null;
    try {
      final response = await ApiService.get('/assessments/$id');
      if (response is! Map) return null;
      final map = Map<String, dynamic>.from(response);
      final responseId = map['id']?.toString();
      if (responseId == null || responseId.isEmpty || responseId != id) {
        return null;
      }
      return SubmittedAssessment.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> existsOnServer(String id) async {
    if (id.isEmpty) return false;
    final found = await getAssessmentById(id);
    return found != null;
  }

  Future<List<SubmittedAssessment>> getPassedAssessments() async {
    final assessments = await getAllAssessments();
    return assessments.where((assessment) => assessment.score >= 90).toList();
  }
}
