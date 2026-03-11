import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/submitted_assessment.dart';
import '../../routes.dart';

class FlaggedEmployeesScreen extends StatelessWidget {
  const FlaggedEmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get filter arguments from navigation
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
    final selectedBU = args?['selectedBU'] ?? 'All BUs';
    final selectedSection = args?['selectedSection'] ?? 'All Sections';

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Flagged Employees${selectedBU != 'All BUs' ? ' - $selectedBU' : ''}${selectedSection != 'All Sections' ? ' - $selectedSection' : ''}'),
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          // Get all flagged assessments
          final flaggedAssessments = appState.assessments
              .where((a) => a.isFlagged && !a.resolved)
              .toList();

          // Apply BU and section filters
          final filteredFlaggedAssessments = flaggedAssessments.where((a) {
            final buMatch = selectedBU == 'All BUs' || a.bu == selectedBU;
            final sectionMatch = selectedSection == 'All Sections' ||
                a.section == selectedSection;
            return buMatch && sectionMatch;
          }).toList();

          // Group by auditee name
          final employees = <String, List<SubmittedAssessment>>{};
          for (final assessment in filteredFlaggedAssessments) {
            employees
                .putIfAbsent(assessment.auditeeName, () => [])
                .add(assessment);
          }

          if (employees.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'No flagged employees found${selectedBU != 'All BUs' ? ' for $selectedBU' : ''}${selectedSection != 'All Sections' ? ' in $selectedSection' : ''}.',
                  style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: employees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final employeeName = employees.keys.elementAt(index);
              final assessments = employees[employeeName]!;
              final latestAssessment = assessments.first;

              // Count total flagged items across all assessments for this employee
              final totalFlaggedItems = assessments.fold<int>(
                  0,
                  (sum, a) =>
                      sum +
                      a.items
                          .where((item) => item['isFlagged'] == true)
                          .length);

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
                  onTap: () {
                    // Navigate to assessment details
                    Navigator.pushNamed(
                      context,
                      Routes.assessmentResults,
                      arguments: {
                        'assessmentId': latestAssessment.id,
                        'businessUnit':
                            latestAssessment.bu ?? latestAssessment.company,
                        'section': latestAssessment.section,
                        'score': latestAssessment.score,
                        'isFlagged': true,
                        'resolved': false,
                        'assessmentData': latestAssessment.items,
                        'auditorName': latestAssessment.auditorName,
                        'auditeeName': latestAssessment.auditeeName,
                        'assessmentDate':
                            latestAssessment.date.toString().split(' ').first,
                      },
                    );
                  },
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.1),
                    child: const Icon(Icons.flag, color: Color(0xFFEF4444)),
                  ),
                  title: Text(
                    employeeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        '${latestAssessment.bu ?? 'N/A'} • ${latestAssessment.section ?? 'N/A'} • ${latestAssessment.score}%\n'
                        '${assessments.length} flagged assessment${assessments.length > 1 ? 's' : ''} • $totalFlaggedItems issue${totalFlaggedItems != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last audit: ${_formatDate(latestAssessment.date)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Color(0x60000000),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year.toString().substring(2)}';
  }
}
