import 'package:flutter/material.dart';
import 'dart:io';
import '../widgets/question_card.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/submitted_assessment.dart';
import '../services/email_service.dart';
import '../services/user_service.dart';
import '../services/question_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final Map<int, String> _answers = {};
  final Map<int, List<File>> _questionImages = {};
  final Map<int, String> _questionComments = {};
  SubmittedAssessment? _editing;
  final QuestionService _questionService = QuestionService();
  List<Map<String, dynamic>> questions = [];
  bool isLoading = true;

  Future<List<String>> _uploadImagesToStorage(
      String assessmentId, int questionIndex, List<File> files) async {
    final storage = FirebaseStorage.instance;
    final List<String> urls = [];

    for (final file in files) {
      try {
        final exists = await file.exists();
        if (!exists) {
          throw Exception('Selected image no longer exists on device.');
        }

        final fileName = file.path.split(Platform.pathSeparator).last;
        final ref = storage
            .ref()
            .child('assessments')
            .child(assessmentId)
            .child('q${questionIndex + 1}')
            .child(fileName);

        await ref.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        // In some environments, download URL generation may briefly lag behind upload.
        String? url;
        Object? lastError;
        for (int attempt = 0; attempt < 3; attempt++) {
          try {
            url = await ref.getDownloadURL();
            break;
          } catch (e) {
            lastError = e;
            if (attempt < 2) {
              await Future.delayed(
                Duration(milliseconds: 500 * (attempt + 1)),
              );
            }
          }
        }

        if (url == null || url.isEmpty) {
          throw Exception(
            'Upload completed but download URL was not available. ${lastError ?? ''}',
          );
        }

        urls.add(url);
      } catch (e) {
        throw Exception(
          'Image upload failed for Question ${questionIndex + 1} (${file.path}): $e',
        );
      }
    }

    return urls;
  }

  @override
  void initState() {
    super.initState();
    print(
        'AssessmentScreen initState - questions list initialized with ${questions.length} items');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('AssessmentScreen didChangeDependencies called');
    _loadQuestions();
    _loadAssessmentData();
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
    print(
        'AssessmentScreen build called - questions.length: ${questions.length}, isLoading: $isLoading');

    return Scaffold(
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
          ? const Center(child: CircularProgressIndicator())
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
                            question: questionData['question'] as String,
                            questionDetails:
                                questionData['details'] as String? ?? '',
                            category: questionData['category'] as String,
                            onAnswer: (answer) {
                              setState(() {
                                _answers[index] = answer;
                              });
                            },
                            onImagesSelected: (images) {
                              setState(() {
                                _questionImages[index] = images;
                              });
                            },
                            onCommentChanged: (comment) {
                              _questionComments[index] = comment;
                            },
                            initialAnswer: _answers[index],
                            initialComment: _questionComments[index],
                            initialImagePath:
                                _questionImages[index]?.isNotEmpty == true
                                    ? _questionImages[index]!.first.path
                                    : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _answers.length == questions.length && !isLoading
            ? () {
                _submitAssessment();
              }
            : null,
        backgroundColor: _answers.length == questions.length && !isLoading
            ? const Color(0xFF0891B2)
            : const Color(0xFF9CA3AF),
        icon: const Icon(Icons.send),
        label: Text(_answers.length == questions.length && !isLoading
            ? (_editing != null ? 'Update Assessment' : 'Submit Assessment')
            : 'Answer All Questions'),
      ),
    );
  }

  Future<void> _submitAssessment() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);

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

      final String assessmentIdForUpload =
          _editing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      final List<Map<String, dynamic>> items = [];
      for (int index = 0; index < totalQuestions; index++) {
        final localPaths = _questionImages[index]
                ?.map((img) => img.path)
                .toList() ??
            <String>[];
        final files = _questionImages[index] ?? <File>[];
        final urls = files.isNotEmpty
            ? await _uploadImagesToStorage(assessmentIdForUpload, index, files)
            : <String>[];

        items.add({
          'question': questions[index]['question'],
          'answer': _answers[index] ?? 'N/A',
          'remarks': _questionComments[index] ?? '',
          'imagePaths': localPaths,
          'imageUrls': urls,
          'isFlagged': (_answers[index] == 'No' || _answers[index] == 'N/A'),
        });
      }

      String assessmentIdToView;

      if (_editing != null) {
        final updated = SubmittedAssessment(
          id: _editing!.id,
          company: _editing!.company,
          auditorName: _editing!.auditorName,
          auditeeName: _editing!.auditeeName,
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
        );

        appState.updateSubmittedAssessment(updated);
        assessmentIdToView = updated.id;

        final emailSent = await EmailService.sendAssessmentEmail(updated);
        if (emailSent) {
          print('Updated assessment email sent successfully');
        } else {
          final error = EmailService.lastError ?? 'Unknown email error.';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Assessment submitted but email failed: $error'),
                backgroundColor: const Color(0xFFEF4444),
                duration: const Duration(seconds: 6),
              ),
            );
          }
        }
      } else {
        final submitted = SubmittedAssessment(
          id: assessmentIdForUpload,
          company: appState.selectedCompany ?? 'Unknown',
          bu: appState.selectedBU,
          section: appState.selectedSection,
          auditorName: appState.auditorName ?? 'Unknown Auditor',
          auditeeName: appState.auditeeName ?? 'Unknown Auditee',
          date: DateTime.now(),
          items: items,
          score: score,
          isFlagged: isFlagged,
          followUpDueAt:
              isFlagged ? DateTime.now().add(const Duration(days: 14)) : null,
        );

        appState.addSubmittedAssessment(submitted);

        assessmentIdToView = submitted.id;

        final emailSent = await EmailService.sendAssessmentEmail(submitted);
        if (emailSent) {
          print('Assessment email sent successfully');
        } else {
          final error = EmailService.lastError ?? 'Unknown email error.';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Assessment submitted but email failed: $error'),
                backgroundColor: const Color(0xFFEF4444),
                duration: const Duration(seconds: 6),
              ),
            );
          }
        }

        // Save assessment to user record
        await _saveAssessmentToUser(submitted);
      }

      Navigator.of(context).pushNamed(
        '/assessmentResults',
        arguments: {
          'assessmentId': assessmentIdToView,
          'showLogoutOnBack': true,
          'businessUnit': _editing?.bu ??
              appState.selectedBU ??
              appState.selectedCompany ??
              'Unknown',
          'score': score,
          'isFlagged': isFlagged,
          'resolved': _editing != null ? !isFlagged : false,
          'assessmentData': items,
          'auditorName': _editing?.auditorName ??
              (appState.auditorName ?? 'Unknown Auditor'),
          'auditeeName': _editing?.auditeeName ??
              (appState.auditeeName ?? 'Unknown Auditee'),
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
      print('Submit assessment failed: $e');
    }
  }

  Future<void> _saveAssessmentToUser(SubmittedAssessment assessment) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('DEBUG: No current user found');
        return;
      }

      // Get employee ID from email
      final employeeId = int.parse(currentUser.email!.split('@').first);
      print('DEBUG: Looking for user with employeeId: $employeeId');

      // Find user document
      final userDoc = await UserService.getUserByEmployeeId(employeeId);
      if (userDoc != null) {
        print('DEBUG: Found user document: ${userDoc.id}');

        // Convert assessment to map for storage
        final assessmentData = {
          'id': assessment.id,
          'company': assessment.company,
          'bu': assessment.bu,
          'section': assessment.section,
          'auditorName': assessment.auditorName,
          'auditeeName': assessment.auditeeName,
          'date': assessment.date.toIso8601String(),
          'items': assessment.items,
          'score': assessment.score,
          'isFlagged': assessment.isFlagged,
          'followUpDueAt': assessment.followUpDueAt?.toIso8601String(),
          'submitted_at': DateTime.now().toIso8601String(),
        };

        print('DEBUG: Saving assessment data: $assessmentData');

        await UserService.addAssessmentToUser(
          userId: userDoc.id,
          assessmentData: assessmentData,
        );

        print('DEBUG: Assessment saved successfully to user record');
      } else {
        print('DEBUG: No user document found for employeeId: $employeeId');
      }
    } catch (e) {
      print('DEBUG: Error saving assessment to user record: $e');
    }
  }
}
