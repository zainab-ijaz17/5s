import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import '../widgets/question_card.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/submitted_assessment.dart';
import '../models/assessment_draft.dart';
import '../services/connectivity_service.dart';
import '../services/question_service.dart';
import '../services/sync_service.dart';
import '../services/assessment_draft_service.dart';
import '../navigation/role_navigation.dart';
import '../services/session_service.dart';
import '../widgets/loading_overlay.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen>
    with WidgetsBindingObserver {
  final Map<int, String> _answers = {};
  final Map<int, List<File>> _questionImages = {};
  final Map<int, String> _questionComments = {};
  SubmittedAssessment? _editing;
  final QuestionService _questionService = QuestionService();
  List<Map<String, dynamic>> questions = [];
  bool isLoading = true;
  bool _isSubmitting = false;
  String? _submitStatusMessage;
  bool _resumeDraft = false;
  bool _draftLoaded = false;
  String? _draftId;
  DateTime? _draftStartedAt;
  /// Cached in [didChangeDependencies] so dispose/lifecycle can save without
  /// looking up Provider ancestors on a deactivated element.
  AppState? _appState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AssessmentDraftService.instance.setAssessmentScreenOpen(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AssessmentDraftService.instance.setAssessmentScreenOpen(false);
    if (_editing == null && !_isSubmitting) {
      unawaited(_persistDraft());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_editing != null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_persistDraft());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = Provider.of<AppState>(context, listen: false);
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _resumeDraft = args?['resumeDraft'] == true;
    _loadQuestions();
    _loadAssessmentData();
  }

  Future<void> _persistDraft() async {
    if (_editing != null || _isSubmitting) return;
    if (questions.isEmpty) return;

    final appState = _appState;
    if (appState == null) return;

    final draftId = _draftId ?? DateTime.now().millisecondsSinceEpoch.toString();
    _draftId = draftId;
    _draftStartedAt ??= DateTime.now();

    // Copy camera/gallery temp files into durable app storage so photos
    // still exist after the app is killed and the draft is continued.
    final durablePaths = await AssessmentDraftService.instance.persistImageFiles(
      draftId: draftId,
      imageFiles: Map<int, List<File>>.from(_questionImages),
    );

    // Point in-memory state at durable files for the rest of this session.
    _questionImages
      ..clear()
      ..addAll(
        durablePaths.map(
          (index, paths) => MapEntry(
            index,
            paths.map(File.new).toList(),
          ),
        ),
      );

    final draft = AssessmentDraft(
      id: draftId,
      userId: appState.currentUser?.id,
      employeeId: appState.currentUser?.employeeId,
      company: appState.selectedCompany ?? 'Unknown',
      bu: appState.selectedBU,
      section: appState.selectedSection,
      auditorName: appState.auditorName,
      auditeeName: appState.auditeeName,
      startedAt: _draftStartedAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      totalQuestions: questions.length,
      answers: Map<int, String>.from(_answers),
      comments: Map<int, String>.from(_questionComments),
      imagePaths: durablePaths,
    );

    await AssessmentDraftService.instance.saveDraft(draft);
  }

  Future<void> _restoreDraftIfNeeded() async {
    if (_editing != null || _draftLoaded || !_resumeDraft || !mounted) return;

    final appState = Provider.of<AppState>(context, listen: false);
    final draft = await AssessmentDraftService.instance.loadDraft(
      userId: appState.currentUser?.id,
      employeeId: appState.currentUser?.employeeId,
    );
    if (draft == null || !mounted) {
      _draftLoaded = true;
      return;
    }

    if (draft.totalQuestions > 0 && draft.totalQuestions != questions.length) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Question list changed since your draft was saved. Starting fresh.',
            ),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
      }
      await AssessmentDraftService.instance.clearDraft();
      _draftLoaded = true;
      return;
    }

    _draftId = draft.id;
    _draftStartedAt = draft.startedAt;

    if (draft.company.isNotEmpty) appState.selectCompany(draft.company);
    if (draft.bu != null && draft.bu!.isNotEmpty) appState.selectBU(draft.bu!);
    appState.selectSection(draft.section);
    final user = appState.currentUser;
    if (user != null &&
        draft.auditorName != null &&
        draft.auditeeName != null) {
      appState.setLogin(
        user,
        auditor: draft.auditorName,
        auditee: draft.auditeeName,
      );
    }

    _answers
      ..clear()
      ..addAll(draft.answers);
    _questionComments
      ..clear()
      ..addAll(draft.comments);
    _questionImages.clear();
    draft.imagePaths.forEach((index, paths) {
      final files = paths
          .where((p) => p.isNotEmpty)
          .map((p) => File(p))
          .where((f) => f.existsSync())
          .toList();
      if (files.isNotEmpty) _questionImages[index] = files;
    });

    _draftLoaded = true;
    if (mounted) setState(() {});
  }

  Future<void> _loadQuestions() async {
    try {
      print('Loading questions from QuestionService...');
      final loadedQuestions = await _questionService.getQuestions();
      print('Loaded ${loadedQuestions.length} questions');
      if (mounted) {
        setState(() {
          questions = loadedQuestions;
          isLoading = false;
        });
        await _restoreDraftIfNeeded();
      }
    } catch (e) {
      print('Error loading questions: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading questions: $e')),
        );
      }
    }
  }

  void _loadAssessmentData() {
    if (_editing == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final SubmittedAssessment? edit =
          args != null ? args['editAssessment'] as SubmittedAssessment? : null;

      if (edit != null) {
        final appState = Provider.of<AppState>(context, listen: false);
        if (!(appState.isPowerUser || appState.isBUManager)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'You do not have permission to edit this assessment.')),
          );
          Navigator.of(context).pop();
          return;
        }

        _editing = edit;
        for (var i = 0; i < edit.items.length; i++) {
          final item = edit.items[i];
          final ans = (item['answer'] as String?) ?? 'N/A';
          final rem = (item['remarks'] as String?) ?? '';
          final img = (item['imagePath'] as String?) ?? '';
          final imgPaths = (item['imagePaths'] as List<String>?) ?? [];
          _answers[i] = ans;
          _questionComments[i] = rem;

          if (imgPaths.isNotEmpty) {
            _questionImages[i] = imgPaths.map((path) => File(path)).toList();
          } else if (img.isNotEmpty) {
            _questionImages[i] = [File(img)];
          }
        }

        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncProgress =
        _isSubmitting ? context.watch<AppState>().syncProgress : null;
    final loadingMessage = syncProgress ??
        _submitStatusMessage ??
        (_editing != null ? 'Updating assessment...' : 'Saving assessment...');

    return PopScope(
      canPop: !_isSubmitting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _editing == null) {
          unawaited(_persistDraft());
        }
      },
      child: LoadingOverlay(
      isLoading: _isSubmitting,
      message: loadingMessage,
      variant: LoadingPanelVariant.submit,
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          _editing != null ? 'Edit Assessment' : 'Assessment',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: questions.isNotEmpty
                  ? (_answers.length / questions.length).clamp(0.0, 1.0)
                  : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF9FAFB),
      body: isLoading
          ? const Center(
              child: LoadingPanel(message: 'Loading questions...'),
            )
          : questions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No questions available',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please contact your administrator to add questions',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF0891B2).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.quiz,
                                  color: Color(0xFF0891B2),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _editing != null
                                      ? 'Resolve Flagged Assessment'
                                      : '5S Methodology Assessment',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0891B2),
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _editing != null
                                ? 'Update answers and remarks to address flagged items. Marking all items compliant will resolve this assessment.'
                                : 'Please answer each question and add photos/comments as needed.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF6B7280),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Progress: ${_answers.length}/${questions.length} questions answered',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF0891B2),
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: questions.length,
                        itemBuilder: (context, index) {
                          final questionData = questions[index];
                          return QuestionCard(
                            key: ValueKey(
                              'q_${index}_${_answers[index]}_'
                              '${_questionImages[index]?.map((f) => f.path).join('|') ?? ''}',
                            ),
                            question: questionData['question'] as String,
                            questionDetails:
                                questionData['details'] as String? ?? '',
                            category: questionData['category'] as String,
                            onAnswer: (answer) {
                              setState(() {
                                _answers[index] = answer;
                              });
                              unawaited(_persistDraft());
                            },
                            onImagesSelected: (images) {
                              setState(() {
                                _questionImages[index] = images;
                              });
                              // Persist immediately so temp picker files are
                              // copied before iOS/Android can delete them.
                              unawaited(() async {
                                await _persistDraft();
                                if (mounted) setState(() {});
                              }());
                            },
                            onCommentChanged: (comment) {
                              _questionComments[index] = comment;
                              unawaited(_persistDraft());
                            },
                            initialAnswer: _answers[index],
                            initialComment: _questionComments[index],
                            initialImagePaths: _questionImages[index]
                                ?.map((img) => img.path)
                                .toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _answers.length == questions.length &&
                !isLoading &&
                !_isSubmitting
            ? () {
                _submitAssessment();
              }
            : null,
        backgroundColor: _answers.length == questions.length &&
                !isLoading &&
                !_isSubmitting
            ? const Color(0xFF0891B2)
            : const Color(0xFF9CA3AF),
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send),
        label: Text(
          _isSubmitting
              ? 'Submitting...'
              : _answers.length == questions.length && !isLoading
                  ? (_editing != null ? 'Update Assessment' : 'Submit Assessment')
                  : 'Answer All Questions',
        ),
      ),
    ),
    ),
    );
  }

  Future<void> _submitAssessment() async {
    if (_isSubmitting) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Still submitting, please wait...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitStatusMessage =
          _editing != null ? 'Updating assessment...' : 'Saving assessment...';
    });
    try {
      final appState = Provider.of<AppState>(context, listen: false);

      if (!await RoleNavigation.ensureAuditorAuditee(context)) {
        return;
      }

      final auditorName = appState.auditorName?.trim() ?? '';
      final auditeeName = appState.auditeeName?.trim() ?? '';
      final company = appState.selectedCompany?.trim() ?? '';
      final bu = appState.selectedBU?.trim();
      final section = appState.selectedSection?.trim();

      if (auditorName.isEmpty || auditeeName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auditor and auditee names are required.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      if (company == 'Packages Convertors Limited' &&
          (section == null || section.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Section is required. Go back and select a section on Take Test.',
            ),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      final totalQuestions = questions.length;

      // Require image only if answer is "No"
      for (int i = 0; i < totalQuestions; i++) {
        final answer = _answers[i];

        if (answer == 'No') {
          final images = _questionImages[i];

          if (images == null || images.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Please upload an image for Question ${i + 1} (answered No).',
                ),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
            return;
          }
        }
      }

      final applicableQuestions =
          _answers.values.where((a) => a != 'N/A').length;

      final yesCount = _answers.values.where((a) => a == 'Yes').length;

      final score = applicableQuestions > 0
          ? ((yesCount / applicableQuestions) * 100).round()
          : 0;

      final isFlagged = score < 90;

      final online = await ConnectivityService.instance.isOnline();
      final String assessmentId =
          _editing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      final List<Map<String, dynamic>> items = [];
      for (int index = 0; index < totalQuestions; index++) {
        final localPaths = _questionImages[index]
                ?.map((img) => img.path)
                .toList() ??
            <String>[];

        items.add({
          'questionId': questions[index]['id']?.toString(),
          'question': questions[index]['question']?.toString() ?? '',
          'category': questions[index]['category']?.toString(),
          'details': questions[index]['details']?.toString(),
          'answer': _answers[index] ?? 'N/A',
          'remarks': _questionComments[index] ?? '',
          'imagePaths': localPaths,
          'imageUrls': <String>[],
          'isFlagged': (_answers[index] == 'No' || _answers[index] == 'N/A'),
        });
      }

      final savedAssessment = _editing != null
          ? SubmittedAssessment(
              id: _editing!.id,
              company: _editing!.company,
              auditorName: _editing!.auditorName,
              auditeeName: _editing!.auditeeName,
              auditorEmail:
                  appState.currentUser?.email ?? _editing!.auditorEmail,
              auditeeEmail: _editing!.auditeeEmail,
              userName: appState.currentUser?.name,
              employeeId: appState.currentUser?.employeeId,
              date: DateTime.now(),
              items: items,
              score: score,
              isFlagged: isFlagged,
              bu: _editing!.bu,
              section: _editing!.section,
              followUpDueAt: isFlagged
                  ? (_editing!.followUpDueAt ??
                      DateTime.now().add(const Duration(days: 14)))
                  : null,
              followUpSent: _editing!.followUpSent,
              resolved: !isFlagged,
              resolvedAt: !isFlagged ? DateTime.now() : null,
              resolvedBy: !isFlagged ? (appState.currentUser?.name) : null,
              pendingSync: true,
            )
          : SubmittedAssessment(
              id: assessmentId,
              company: company.isNotEmpty ? company : 'Unknown',
              bu: bu != null && bu.isNotEmpty ? bu : null,
              section: section != null && section.isNotEmpty ? section : null,
              auditorName: auditorName,
              auditeeName: auditeeName,
              auditorEmail: appState.currentUser?.email,
              userName: appState.currentUser?.name,
              employeeId: appState.currentUser?.employeeId,
              date: DateTime.now(),
              items: items,
              score: score,
              isFlagged: isFlagged,
              followUpDueAt:
                  isFlagged ? DateTime.now().add(const Duration(days: 14)) : null,
              pendingSync: true,
            );

      await SessionService.instance.saveAssessmentContext(
        auditor: auditorName,
        auditee: auditeeName,
        company: savedAssessment.company,
        bu: savedAssessment.bu,
        section: savedAssessment.section,
      );

      if (_editing != null) {
        appState.updateSubmittedAssessment(savedAssessment);
      } else {
        appState.addSubmittedAssessment(savedAssessment);
      }

      // Keep draft image files until sync uploads them (deleteImages: false).
      await AssessmentDraftService.instance.clearDraft(deleteImages: false);

      if (!mounted) return;

      if (online) {
        setState(() {
          _submitStatusMessage = 'Uploading to server...';
        });
        final result =
            await SyncService.instance.syncPendingAssessments(appState);
        if (!mounted) return;

        final savedToServer = !appState.assessments.any(
          (a) => a.id == savedAssessment.id && a.pendingSync,
        );

        if (savedToServer) {
          final emailMessage = result.emailQueued
              ? 'Assessment saved to server. Notification email will be sent by the server.'
              : result.emailSent == true
                  ? 'Assessment saved to server. Notification email sent.'
                  : result.emailSent == false
                      ? 'Assessment saved to server. Email not sent: ${result.emailError ?? 'unknown error'}.'
                      : 'Assessment saved to server.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(emailMessage),
              backgroundColor: result.emailSent == false
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF10B981),
              duration: Duration(seconds: result.emailSent == false ? 8 : 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.lastError ??
                    'Saved on this device only. Could not reach server — tap the orange banner to retry.',
              ),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 8),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No internet. Assessment saved on this device and will sync when online.',
            ),
            backgroundColor: Color(0xFFF59E0B),
            duration: Duration(seconds: 5),
          ),
        );
      }

      await Navigator.of(context).pushNamed(
        '/assessmentResults',
        arguments: {
          'assessmentId': savedAssessment.id,
          'showHomeButton': true,
          'businessUnit': _editing?.bu ??
              savedAssessment.bu ??
              appState.selectedBU ??
              appState.selectedCompany ??
              'Unknown',
          'section': _editing?.section ??
              savedAssessment.section ??
              appState.selectedSection,
          'score': score,
          'isFlagged': isFlagged,
          'resolved': _editing != null ? !isFlagged : false,
          'assessmentData': items,
          'auditorName': _editing?.auditorName ?? auditorName,
          'auditeeName': _editing?.auditeeName ?? auditeeName,
          'assessmentDate': DateTime.now().toString().split(' ')[0],
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submit failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 6),
          ),
        );
      }
      debugPrint('Submit assessment failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitStatusMessage = null;
        });
      }
    }
  }
}
