import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../routes.dart';
import '../services/connectivity_service.dart';
import '../services/assessment_service.dart';
import '../state/app_state.dart';
import '../models/submitted_assessment.dart';
import '../util/assessment_item_util.dart';
import '../widgets/loading_overlay.dart';

class AssessmentResultsScreen extends StatefulWidget {
  const AssessmentResultsScreen({super.key});

  @override
  State<AssessmentResultsScreen> createState() => _AssessmentResultsScreenState();
}

class _AssessmentResultsScreenState extends State<AssessmentResultsScreen> {
  final AssessmentService _assessmentService = AssessmentService();
  SubmittedAssessment? _fetchedAssessment;
  bool _loadingDetails = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAssessment());
  }

  Future<void> _loadAssessment() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final assessmentId = args?['assessmentId'] as String?;
    if (assessmentId == null) return;

    final online = await ConnectivityService.instance.isOnline();
    if (!online) return;

    setState(() {
      _loadingDetails = true;
      _loadError = null;
    });

    try {
      final fetched = await _assessmentService.getAssessmentById(assessmentId);
      if (!mounted) return;

      if (fetched != null) {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.upsertSubmittedAssessment(fetched);
        setState(() {
          _fetchedAssessment = fetched;
          _loadingDetails = false;
        });
        return;
      }

      setState(() {
        _loadingDetails = false;
        _loadError = 'Assessment not found on server.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDetails = false;
        _loadError = 'Could not load assessment details.';
      });
    }
  }

  List<Map<String, dynamic>> _resolveAssessmentItems(
    SubmittedAssessment? sa,
    Map<String, dynamic>? args,
  ) {
    final fromFetched = AssessmentItemUtil.parseItems(_fetchedAssessment?.items);
    if (fromFetched.isNotEmpty) return fromFetched;

    final fromState = AssessmentItemUtil.parseItems(sa?.items);
    if (fromState.isNotEmpty) return fromState;

    return AssessmentItemUtil.parseItems(args?['assessmentData']);
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? assessmentId = args?['assessmentId'] as String?;
    final bool showHomeButton =
        args?['showHomeButton'] == true || args?['showLogoutOnBack'] == true;

    SubmittedAssessment? sa = _fetchedAssessment;
    if (sa == null && assessmentId != null) {
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
    final assessmentData = _resolveAssessmentItems(sa, args);
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
        automaticallyImplyLeading: !showHomeButton,
        leading: showHomeButton
            ? IconButton(
                icon: const Icon(Icons.home),
                tooltip: 'Back to Home',
                onPressed: () => _goHome(context),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
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
              child: _loadingDetails
                  ? const Center(
                      child: LoadingPanel(
                        message: 'Loading assessment details...',
                      ),
                    )
                  : assessmentData.isNotEmpty
                      ? ListView.builder(
                          padding: EdgeInsets.only(bottom: showHomeButton ? 8 : 0),
                          itemCount: assessmentData.length,
                          itemBuilder: (context, index) {
                            final questionData = assessmentData[index];
                            final questionText =
                                questionData['question']?.toString().trim();
                            final imageList =
                                AssessmentItemUtil.imagePathsFromItem(
                                    questionData);

                            return _buildQuestionResultCard(
                              questionText?.isNotEmpty == true
                                  ? questionText!
                                  : 'Question ${index + 1}',
                              questionData['category']?.toString() ?? 'GENERAL',
                              questionData['details']?.toString() ?? '',
                              questionData['answer']?.toString() ?? 'No answer',
                              questionData['remarks']?.toString() ?? '',
                              imageList,
                              questionData['isFlagged'] == true,
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            _loadError ??
                                'No assessment data available',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF6B7280),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: showHomeButton
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _goHome(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0891B2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.home),
                    label: const Text(
                      'Back to Home',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  void _goHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      Routes.takeTest,
      (route) => false,
    );
  }

  Color _getAnswerColor(String answer) {
    switch (answer.toLowerCase()) {
      case 'yes':
        return const Color(0xFF10B981);
      case 'no':
        return const Color(0xFFEF4444);
      case 'n/a':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF0891B2);
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

  Widget _buildQuestionResultCard(
    String questionText,
    String category,
    String details,
    String answer,
    String remarks,
    List<String> images,
    bool isFlagged,
  ) {
    bool isExpanded = false;
    return StatefulBuilder(
      builder: (context, setState) {
        final answerColor = _getAnswerColor(answer);
        final normalizedCategory = category.toUpperCase();

        final categoryColors = {
          'SORT': const Color(0xFF3B82F6),
          'SET': const Color(0xFF10B981),
          'SHINE': const Color(0xFFF59E0B),
          'STANDARDIZE': const Color(0xFF8B5CF6),
          'SUSTAIN': const Color(0xFFEC4899),
        };

        final categoryColor =
            categoryColors[normalizedCategory] ?? const Color(0xFF0891B2);

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
                        normalizedCategory,
                        style: TextStyle(
                          color: categoryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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
