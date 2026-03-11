import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

// ... existing imports ...

class ObservationsScreen extends StatelessWidget {
  const ObservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Observations'),
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          // Get all assessments with remarks
          final observations = <Map<String, dynamic>>[];

          for (final assessment in appState.assessments) {
            for (final item in assessment.items) {
              final remarks = item['remarks'] as String?;
              if (remarks != null && remarks.isNotEmpty) {
                observations.add({
                  'company': assessment.company,
                  'bu': assessment.bu ?? 'N/A',
                  'section': assessment.section ?? 'N/A',
                  'author': assessment.auditorName,
                  'date': assessment.date,
                  'text': remarks,
                  'assessmentId': assessment.id,
                  'isFlagged': item['isFlagged'] == true,
                });
              }
            }
          }

          // Sort by date (newest first)
          observations.sort((a, b) =>
              (b['date'] as DateTime).compareTo(a['date'] as DateTime));

          if (observations.isEmpty) {
            return const Center(
              child: Text('No observations found.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: observations.length,
            itemBuilder: (context, index) {
              final obs = observations[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: obs['isFlagged'] == true
                      ? const BorderSide(color: Colors.red, width: 1)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company, BU, Section row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  obs['company'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${obs['bu']} • ${obs['section']}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatDate(obs['date'] as DateTime),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (obs['isFlagged'] == true)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: const Text(
                                'Flagged',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 20, thickness: 1),
                      // Remark text
                      Text(
                        obs['text'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF334155),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Author and date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'By: ${obs['author']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          Text(
                            'ID: ${obs['assessmentId']}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
