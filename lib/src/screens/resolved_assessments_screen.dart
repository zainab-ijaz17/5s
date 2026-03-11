import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/submitted_assessment.dart';
import '../state/app_state.dart';
import '../../routes.dart';

class PassedAssessmentsScreen extends StatefulWidget {
  const PassedAssessmentsScreen({super.key});

  @override
  State<PassedAssessmentsScreen> createState() =>
      _PassedAssessmentsScreenState();
}

class _PassedAssessmentsScreenState extends State<PassedAssessmentsScreen> {
  late Future<List<SubmittedAssessment>> _assessmentsFuture;
  String? selectedBU;
  String? selectedSection;
  bool _initializedFromArgs = false;

  @override
  void initState() {
    super.initState();
    // Initialize with empty future to avoid LateInitializationError
    _assessmentsFuture = Future.value([]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromArgs) return;
    _initializedFromArgs = true;

    final argsRaw = ModalRoute.of(context)?.settings.arguments;
    final args = argsRaw is Map ? argsRaw : null;
    selectedBU = args?['selectedBU']?.toString() ?? 'All BUs';
    selectedSection = args?['selectedSection']?.toString() ?? 'All Sections';

    setState(() {
      _assessmentsFuture = _getPassedAssessments();
    });
  }

  Future<List<SubmittedAssessment>> _getPassedAssessments() async {
    // Get all assessments from AppState
    final appState = Provider.of<AppState>(context, listen: false);

    // Filter for passed assessments (not flagged or resolved)
    final passedAssessments = appState.assessments
        .where((assessment) => !assessment.isFlagged || assessment.resolved)
        .toList();

    // Apply BU and section filters if provided
    final filteredPassedAssessments = passedAssessments.where((a) {
      final buMatch = selectedBU == null ||
          selectedBU == 'All BUs' ||
          (a.bu ?? '') == selectedBU;
      final sectionMatch = selectedSection == null ||
          selectedSection == 'All Sections' ||
          (a.section ?? '') == selectedSection;
      return buMatch && sectionMatch;
    }).toList();

    // Sort by date (newest first)
    filteredPassedAssessments.sort((a, b) => b.date.compareTo(a.date));

    return filteredPassedAssessments;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Passed Assessments${selectedBU != null && selectedBU != 'All BUs' ? ' - $selectedBU' : ''}${selectedSection != null && selectedSection != 'All Sections' ? ' - $selectedSection' : ''}'),
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: FutureBuilder<List<SubmittedAssessment>>(
        future: _assessmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading assessments: ${snapshot.error}'),
            );
          }

          final passedAssessments = snapshot.data ?? [];

          if (passedAssessments.isEmpty) {
            return Center(
              child: Text(
                'No passed assessments found${selectedBU != null && selectedBU != 'All BUs' ? ' for $selectedBU' : ''}${selectedSection != null && selectedSection != 'All Sections' ? ' in $selectedSection' : ''}.',
                style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: passedAssessments.length,
            itemBuilder: (context, index) {
              final assessment = passedAssessments[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text('${assessment.bu} - ${assessment.section}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Auditee: ${assessment.auditeeName}'),
                      Text('Auditor: ${assessment.auditorName}'),
                      Text('Date: ${_formatDate(assessment.date)}'),
                      if (assessment.resolvedAt != null)
                        Text('Passed: ${_formatDate(assessment.resolvedAt!)}'),
                      Text('Score: ${assessment.score}%'),
                    ],
                  ),
                  trailing:
                      const Icon(Icons.chevron_right, color: Color(0xFF0891B2)),
                  onTap: () {
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
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
