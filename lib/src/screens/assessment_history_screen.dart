
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/submitted_assessment.dart';
import '../../routes.dart';

class AssessmentHistoryScreen extends StatelessWidget {
  const AssessmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
    final selectedBU =
        args?['selectedBU'] ?? appState.powerUserSelectedBU ?? 'All BUs';
    final selectedSection = args?['selectedSection'] ??
        appState.powerUserSelectedSection ??
        'All Sections';

    final items = appState.assessments
        .where((a) {
          final buMatch = selectedBU == 'All BUs' || (a.bu ?? '') == selectedBU;
          final sectionMatch = selectedSection == 'All Sections' ||
              (a.section ?? '') == selectedSection;
          return buMatch && sectionMatch;
        })
        .toList()
        .reversed
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Assessment History${selectedBU != 'All BUs' ? ' - $selectedBU' : ''}${selectedSection != 'All Sections' ? ' - $selectedSection' : ''}'),
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    Routes.previousAssessments,
                    arguments: {
                      'selectedBU': selectedBU,
                      'selectedSection': selectedSection,
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0891B2),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.history),
                label: const Text('View Previous Assessments'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No assessments yet'))
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final SubmittedAssessment sa = items[index];
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
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              sa.bu ?? sa.company,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                    'Date: ${sa.date.toString().split(' ').first}'),
                                Text('Score: ${sa.score}%'),
                                if (sa.section != null)
                                  Text('Section: ${sa.section}'),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: sa.resolved
                                            ? const Color(0xFF10B981)
                                                .withOpacity(0.1)
                                            : sa.isFlagged
                                                ? const Color(0xFFEF4444)
                                                    .withOpacity(0.1)
                                                : const Color(0xFF10B981)
                                                    .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        sa.resolved
                                            ? 'Resolved (${sa.score}%)'
                                            : sa.isFlagged
                                                ? 'Flagged (${sa.score}%)'
                                                : 'Passed (${sa.score}%)',
                                        style: TextStyle(
                                          color: sa.resolved
                                              ? const Color(0xFF10B981)
                                              : sa.isFlagged
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFF10B981),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      Routes.assessmentResults,
                                      arguments: {
                                        'assessmentId': sa.id,
                                        'businessUnit': sa.bu ?? sa.company,
                                        'section': sa.section,
                                        'score': sa.score,
                                        'isFlagged': sa.isFlagged,
                                        'resolved': sa.resolved,
                                        'assessmentData': sa.items,
                                        'auditorName': sa.auditorName,
                                        'auditeeName': sa.auditeeName,
                                        'assessmentDate':
                                            sa.date.toString().split(' ').first,
                                        'resolvedAt':
                                            sa.resolvedAt?.toIso8601String(),
                                        'resolvedBy': sa.resolvedBy,
                                      },
                                    );
                                  },
                                  child: const Text('View'),
                                ),
                                if (sa.isFlagged &&
                                    !sa.resolved &&
                                    (appState.isPowerUser ||
                                        appState.isBUManager))
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        Routes.assessment,
                                        arguments: {
                                          'editAssessment': sa,
                                        },
                                      );
                                    },
                                    child: const Text('Edit'),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
