import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../routes.dart';
import '../state/app_state.dart';
import '../models/submitted_assessment.dart';

class AssessmentResultsScreen extends StatelessWidget {
  const AssessmentResultsScreen({super.key});

  List<Map<String, dynamic>> _normalizeItems(dynamic rawItems) {
    if (rawItems is List<Map<String, dynamic>>) return rawItems;
    if (rawItems is List) {
      return rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> _fetchAssessmentItemsFromFirestore(
      String assessmentId) async {
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('company')
        .doc('main')
        .collection('users')
        .get();

    for (final userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      final assessments = userData['assessments'];
      if (assessments is! List) continue;

      for (final a in assessments) {
        if (a is! Map) continue;
        final aMap = Map<String, dynamic>.from(a);
        final id = aMap['id']?.toString();
        if (id != assessmentId) continue;

        final rawItems =
            aMap['items'] ?? aMap['assessmentData'] ?? aMap['data'];
        if (rawItems is List) {
          return List<Map<String, dynamic>>.from(rawItems
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e)));
        }

        return <Map<String, dynamic>>[];
      }
    }

    return <Map<String, dynamic>>[];
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? assessmentId = args?['assessmentId'] as String?;
    final bool showLogoutOnBack = args?['showLogoutOnBack'] == true;

    SubmittedAssessment? sa;
    if (assessmentId != null) {
      final appState = Provider.of<AppState>(context);
      for (final a in appState.assessments) {
        if (a.id == assessmentId) {
          sa = a;
          break;
        }
      }
    }

    final businessUnit =
        sa?.bu ?? (args?['businessUnit'] as String?) ?? 'Unknown Unit';
    final section =
        sa?.section ?? (args?['section'] as String?) ?? 'Unknown Section';
    final score = sa?.score ?? (args?['score'] as int?) ?? 0;
    final isFlagged = sa?.isFlagged ?? (args?['isFlagged'] as bool?) ?? false;
    final bool resolved = sa?.resolved ?? (args?['resolved'] as bool?) ?? false;
    final assessmentData =
        _normalizeItems(sa?.items ?? args?['assessmentData']);
    final auditorName = sa?.auditorName ??
        (args?['auditorName'] as String?) ??
        'Unknown Auditor';
    final auditeeName = sa?.auditeeName ??
        (args?['auditeeName'] as String?) ??
        'Unknown Auditee';
    final assessmentDate = sa?.date.toString().split(' ').first ??
        (args?['assessmentDate'] as String?) ??
        DateTime.now().toString().split(' ')[0];
    final String? resolvedAt = args?['resolvedAt'] as String?;
    final String? resolvedBy = args?['resolvedBy'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          '$businessUnit Results',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(showLogoutOnBack ? Icons.logout : Icons.arrow_back),
          onPressed: () async {
            if (showLogoutOnBack) {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  Routes.login,
                  (route) => false,
                );
              }
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assessment Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auditor: $auditorName',
                              style: const TextStyle(
                                  fontSize: 14, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Auditee: $auditeeName',
                              style: const TextStyle(
                                  fontSize: 14, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Section: $section',
                              style: const TextStyle(
                                  fontSize: 14, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Date: $assessmentDate',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: resolved
                              ? const Color(0xFF10B981).withOpacity(0.1)
                              : isFlagged
                                  ? const Color(0xFFEF4444).withOpacity(0.1)
                                  : const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: resolved
                                ? const Color(0xFF10B981).withOpacity(0.3)
                                : isFlagged
                                    ? const Color(0xFFEF4444).withOpacity(0.3)
                                    : const Color(0xFF10B981).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              resolved
                                  ? Icons.verified
                                  : isFlagged
                                      ? Icons.flag
                                      : Icons.check_circle,
                              size: 16,
                              color: resolved
                                  ? const Color(0xFF10B981)
                                  : isFlagged
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              resolved
                                  ? 'Resolved ($score%)'
                                  : isFlagged
                                      ? 'Flagged ($score%)'
                                      : 'Passed ($score%)',
                              style: TextStyle(
                                color: resolved
                                    ? const Color(0xFF10B981)
                                    : isFlagged
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (resolved &&
                          (resolvedBy != null || resolvedAt != null)) ...[
                        const SizedBox(width: 8),
                        Text(
                          'By ${resolvedBy ?? 'N/A'} on ${resolvedAt != null ? resolvedAt.split('T').first : 'N/A'}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Question Responses',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: assessmentData.isNotEmpty
                  ? ListView.builder(
                      itemCount: assessmentData.length,
                      itemBuilder: (context, index) {
                        final questionData = assessmentData[index];

                        final List<String> imageList = [];
                        final imageUrlsRaw = questionData['imageUrls'];
                        if (imageUrlsRaw is List) {
                          imageList.addAll(imageUrlsRaw
                              .map((e) => e.toString())
                              .where((e) => e.isNotEmpty));
                        }

                        final legacySingle =
                            questionData['imagePath']?.toString();
                        if (legacySingle != null && legacySingle.isNotEmpty) {
                          imageList.add(legacySingle);
                        }

                        final imagePathsRaw = questionData['imagePaths'];
                        if (imagePathsRaw is List) {
                          imageList.addAll(imagePathsRaw
                              .map((e) => e.toString())
                              .where((e) => e.isNotEmpty));
                        }

                        return _buildQuestionResultCard(
                          questionData['question'] ?? 'Question ${index + 1}',
                          questionData['answer']?.toString() ?? 'No answer',
                          questionData['remarks']?.toString() ?? '',
                          imageList,
                          questionData['isFlagged'] == true,
                        );
                      },
                    )
                  : (assessmentId == null
                      ? const Center(
                          child: Text(
                            'No assessment data available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        )
                      : FutureBuilder<List<Map<String, dynamic>>>(
                          future:
                              _fetchAssessmentItemsFromFirestore(assessmentId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            final remoteItems =
                                snapshot.data ?? const <Map<String, dynamic>>[];

                            if (remoteItems.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No assessment data available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: remoteItems.length,
                              itemBuilder: (context, index) {
                                final questionData = remoteItems[index];

                                final List<String> imageList = [];
                                final imageUrlsRaw = questionData['imageUrls'];
                                if (imageUrlsRaw is List) {
                                  imageList.addAll(imageUrlsRaw
                                      .map((e) => e.toString())
                                      .where((e) => e.isNotEmpty));
                                }

                                final legacySingle =
                                    questionData['imagePath']?.toString();
                                if (legacySingle != null &&
                                    legacySingle.isNotEmpty) {
                                  imageList.add(legacySingle);
                                }

                                final imagePathsRaw =
                                    questionData['imagePaths'];
                                if (imagePathsRaw is List) {
                                  imageList.addAll(imagePathsRaw
                                      .map((e) => e.toString())
                                      .where((e) => e.isNotEmpty));
                                }

                                return _buildQuestionResultCard(
                                  questionData['question'] ??
                                      'Question ${index + 1}',
                                  questionData['answer']?.toString() ??
                                      'No answer',
                                  questionData['remarks']?.toString() ?? '',
                                  imageList,
                                  questionData['isFlagged'] == true,
                                );
                              },
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAnswerColor(String answer) {
    switch (answer.toLowerCase()) {
      case 'yes':
        return const Color(0xFF10B981); // Green
      case 'no':
        return const Color(0xFFEF4444); // Red
      case 'n/a':
        return const Color(0xFF6B7280); // Gray
      default:
        return const Color(0xFF0891B2); // Blue
    }
  }

  IconData _getAnswerIcon(String answer) {
    switch (answer.toLowerCase()) {
      case 'yes':
        return Icons.check_circle;
      case 'no':
        return Icons.cancel;
      case 'n/a':
        return Icons.remove_circle;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildExpandableContent(String remarks, List<String> images) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (remarks.isNotEmpty) ...[
          const Text(
            'REMARKS',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            remarks,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (images.isNotEmpty) ...[
          const Text(
            'ATTACHED IMAGE',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: images.map((imagePath) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imagePath.startsWith('http')
                      ? Image.network(
                          imagePath,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 200,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 200,
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.broken_image,
                                    size: 48, color: Colors.grey),
                              ),
                            );
                          },
                        )
                      : Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 200,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 200,
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.broken_image,
                                    size: 48, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                ),
              );
            }).toList(),
          )
        ],
      ],
    );
  }

  Widget _buildQuestionResultCard(dynamic question, String answer,
      String remarks, List<String> images, bool isFlagged) {
    bool isExpanded = false;
    return StatefulBuilder(
      builder: (context, setState) {
        final answerColor = _getAnswerColor(answer);

        // Handle both string and map question types
        String questionText;
        String category = 'GENERAL';
        String details = '';

        if (question is Map<String, dynamic>) {
          questionText = question['question']?.toString() ?? 'Question';
          category = question['category']?.toString() ?? 'GENERAL';
          details = question['details']?.toString() ?? '';
        } else if (question is String) {
          questionText = question;
        } else {
          questionText = 'Question';
        }

        // Define colors for each 5S category
        final categoryColors = {
          'SORT': const Color(0xFF3B82F6), // Blue
          'SET': const Color(0xFF10B981), // Green
          'SHINE': const Color(0xFFF59E0B), // Amber
          'STANDARDIZE': const Color(0xFF8B5CF6), // Purple
          'SUSTAIN': const Color(0xFFEC4899), // Pink
        };

        final categoryColor =
            categoryColors[category] ?? const Color(0xFF0891B2);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isFlagged ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
              width: isFlagged ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => isExpanded = !isExpanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: categoryColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: categoryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Question text
                    Text(
                      questionText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Answer section
                    Row(
                      children: [
                        Icon(
                          _getAnswerIcon(answer),
                          color: answerColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            answer,
                            style: TextStyle(
                              color: answerColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Show more/less button if there are details, remarks, or an image
                    if (details.isNotEmpty ||
                        remarks.isNotEmpty ||
                        images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => setState(() => isExpanded = !isExpanded),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isExpanded ? 'Show less' : 'Show details',
                              style: TextStyle(
                                color: categoryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: categoryColor,
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Expandable content
                    if (isExpanded) ...[
                      const SizedBox(height: 12),
                      if (details.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'GUIDANCE',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                details,
                                style: const TextStyle(
                                  color: Color(0xFF334155),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (remarks.isNotEmpty || images.isNotEmpty)
                        _buildExpandableContent(remarks, images),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
