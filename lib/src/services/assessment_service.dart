import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../models/submitted_assessment.dart';
import '../state/app_state.dart';

class AssessmentService {
  // Singleton pattern
  static final AssessmentService _instance = AssessmentService._internal();
  factory AssessmentService() => _instance;
  AssessmentService._internal();

  // Get all passed assessments from AppState
  Future<List<SubmittedAssessment>> getPassedAssessments(
      BuildContext context) async {
    // Get AppState using the provided context
    final appState = Provider.of<AppState>(context, listen: false);

    // Filter for passed assessments (score >= 90)
    final passedAssessments = appState.assessments
        .where((assessment) => assessment.score >= 90)
        .toList();

    return passedAssessments;
  }

  // Get passed assessments for a specific BU
  Future<List<SubmittedAssessment>> getPassedAssessmentsByBU(
      BuildContext context, String bu) async {
    final assessments = await getPassedAssessments(context);
    return assessments.where((a) => a.bu == bu).toList();
  }

  // Get passed assessments for a specific section
  Future<List<SubmittedAssessment>> getPassedAssessmentsBySection(
      BuildContext context, String section) async {
    final assessments = await getPassedAssessments(context);
    return assessments.where((a) => a.section == section).toList();
  }
}
