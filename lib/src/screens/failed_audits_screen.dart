import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/submitted_assessment.dart';
import '../services/assessment_service.dart';
import '../../routes.dart';

class FailedAuditsScreen extends StatefulWidget {
  const FailedAuditsScreen({super.key});

  @override
  State<FailedAuditsScreen> createState() => _FailedAuditsScreenState();
}

class _FailedAuditsScreenState extends State<FailedAuditsScreen> {
  final AssessmentService _assessmentService = AssessmentService();
  late Future<List<SubmittedAssessment>> _failedAssessmentsFuture;
  String? selectedBU;
  String? selectedSection;
  bool _initializedFromArgs = false;

  @override
  void initState() {
    super.initState();
    _failedAssessmentsFuture = Future.value([]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromArgs) return;
    _initializedFromArgs = true;

    final argsRaw = ModalRoute.of(context)?.settings.arguments;
    final args = argsRaw is Map ? argsRaw : null;
    selectedBU = args?['selectedBU']?.toString();
    selectedSection = args?['selectedSection']?.toString();
    _failedAssessmentsFuture = _getFailedAssessments();
  }

  Future<List<SubmittedAssessment>> _getFailedAssessments() async {
    // Get all assessments from AppState
    final appState = Provider.of<AppState>(context, listen: false);

    // Filter for failed (flagged and not resolved) assessments
    final failedAssessments = appState.assessments
        .where((assessment) => assessment.isFlagged && !assessment.resolved)
        .toList();

    // Apply BU and section filters if provided
    final filteredFailedAssessments = failedAssessments.where((a) {
      final buMatch =
          selectedBU == null || selectedBU == 'All BUs' || a.bu == selectedBU;
      final sectionMatch = selectedSection == null ||
          selectedSection == 'All Sections' ||
          a.section == selectedSection;
      return buMatch && sectionMatch;
    }).toList();

    // Sort by date (newest first)
    filteredFailedAssessments.sort((a, b) => b.date.compareTo(a.date));

    return filteredFailedAssessments;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Failed Audits${selectedBU != null && selectedBU != 'All BUs' ? ' - $selectedBU' : ''}${selectedSection != null && selectedSection != 'All Sections' ? ' - $selectedSection' : ''}'),
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: FutureBuilder<List<SubmittedAssessment>>(
        future: _failedAssessmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading failed audits: ${snapshot.error}'),
            );
          }

          final failedAssessments = snapshot.data ?? [];

          if (failedAssessments.isEmpty) {
            return const Center(
              child: Text('No failed audits found.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: failedAssessments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final assessment = failedAssessments[index];

              // Get the first flagged item's details as the reason
              final flaggedItem = assessment.items.firstWhere(
                (item) => item['isFlagged'] == true,
                orElse: () => {'question': 'N/A'},
              );

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading:
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                  title: Text(
                      '${assessment.bu ?? 'N/A'} · ${assessment.section ?? 'N/A'} · ${assessment.score}%'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date: ${_formatDate(assessment.date)}'),
                      Text('Score: ${assessment.score}%'),
                      Text('Auditor: ${assessment.auditorName}'),
                      Text('Auditee: ${assessment.auditeeName}'),
                      if (flaggedItem['question'] != null)
                        Text('Issue: ${flaggedItem['question']}'),
                      if (flaggedItem['remarks'] != null)
                        Text('Remarks: ${flaggedItem['remarks']}'),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        Routes.assessmentResults,
                        arguments: {
                          'assessmentId': assessment.id,
                          'businessUnit': assessment.bu ?? assessment.company,
                          'section': assessment.section,
                          'score': assessment.score,
                          'isFlagged': assessment.isFlagged,
                          'resolved': assessment.resolved,
                          // Pass local items if present; results screen will fallback to Firestore.
                          'assessmentData': assessment.items,
                          'auditorName': assessment.auditorName,
                          'auditeeName': assessment.auditeeName,
                          'assessmentDate':
                              assessment.date.toString().split(' ').first,
                        },
                      );
                    },
                    child: const Text('View'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
