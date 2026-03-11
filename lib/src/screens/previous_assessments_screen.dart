import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routes.dart';
import '../state/app_state.dart';
import '../models/submitted_assessment.dart';

class PreviousAssessmentsScreen extends StatelessWidget {
  const PreviousAssessmentsScreen({super.key});

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

    // All previous attempts (most recent first)
    final List<SubmittedAssessment> all = appState.assessments
        .where((a) {
          final buMatch = selectedBU == 'All BUs' || (a.bu ?? '') == selectedBU;
          final sectionMatch = selectedSection == 'All Sections' ||
              (a.section ?? '') == selectedSection;
          return buMatch && sectionMatch;
        })
        .toList()
        .reversed
        .toList();
    // Local state via ValueNotifier to avoid converting to StatefulWidget
    final ValueNotifier<bool> flaggedOnly = ValueNotifier<bool>(false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Previous Assessments${selectedBU != 'All BUs' ? ' - $selectedBU' : ''}${selectedSection != 'All Sections' ? ' - $selectedSection' : ''}'),
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
        child: ValueListenableBuilder<bool>(
          valueListenable: flaggedOnly,
          builder: (context, onlyFlagged, _) {
            final items = onlyFlagged
                ? all.where((a) => a.isFlagged && !a.resolved).toList()
                : all;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Attempts',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    FilterChip(
                      label: const Text('Flagged only'),
                      selected: onlyFlagged,
                      onSelected: (v) => flaggedOnly.value = v,
                      selectedColor: const Color(0xFFEF4444).withOpacity(0.15),
                      checkmarkColor: const Color(0xFFEF4444),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('No assessments found'))
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final sa = items[index];
                            final canResolve = (appState.isPowerUser ||
                                    appState.isBUManager) &&
                                sa.isFlagged &&
                                !sa.resolved;
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
                                title: Text(
                                    '${sa.bu ?? sa.company} · ${sa.score}%'),
                                subtitle: Text(
                                  'Section: ${sa.section ?? '-'}\nDate: ${sa.date.toString().split(' ').first}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // View Button
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
                                            'assessmentDate': sa.date
                                                .toString()
                                                .split(' ')
                                                .first,
                                            'resolvedAt': sa.resolvedAt
                                                ?.toIso8601String(),
                                            'resolvedBy': sa.resolvedBy,
                                          },
                                        );
                                      },
                                      child: const Text('View',
                                          style: TextStyle(
                                              color: Color(0xFF0891B2))),
                                    ),
                                    // Resolve Button or Status Icon
                                    if (canResolve)
                                      TextButton(
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text(
                                                  'Resolve Assessment'),
                                              content: const Text(
                                                  'Mark this flagged assessment as resolved?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child: const Text('Resolve'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            appState.resolveAssessment(sa.id,
                                                resolvedBy:
                                                    appState.currentUser?.name);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'Assessment marked as resolved.')),
                                            );
                                          }
                                        },
                                        child: const Text('Resolve',
                                            style: TextStyle(
                                                color: Color(0xFFEF4444))),
                                      )
                                    else if (sa.resolved)
                                      const Icon(Icons.verified,
                                          color: Color(0xFF10B981))
                                    else if (sa.isFlagged)
                                      const Icon(Icons.flag,
                                          color: Color(0xFFEF4444))
                                    else
                                      const Icon(Icons.check_circle,
                                          color: Color(0xFF10B981)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
