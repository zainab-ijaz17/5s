import 'package:flutter/material.dart';
import '../services/follow_up_service.dart';
import '../services/email_service.dart';
import '../../routes.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/submitted_assessment.dart';

class PowerUserDashboardScreen extends StatefulWidget {
  const PowerUserDashboardScreen({super.key});

  @override
  State<PowerUserDashboardScreen> createState() =>
      _PowerUserDashboardScreenState();
}

class _PowerUserDashboardScreenState extends State<PowerUserDashboardScreen> {
  String selectedBU = 'BUFC'; // Default BU
  String selectedSection = 'All Sections';
  DateTimeRange? selectedDateRange;
  String filterPeriod = 'All Time';
  int _totalAssessmentsCount = 0;
  int _passedAssessmentsCount = 0;
  int _flaggedAssessmentsCount = 0;
  int _flaggedEmployeesCount = 0;
  double _averageScore = 0.0;
  bool _isFetchingAssessments = false;

  @override
  void initState() {
    super.initState();
    _fetchAssessmentsForPowerUser().then((_) => _loadAssessmentCounts());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = Provider.of<AppState>(context);
    final storedBU = appState.powerUserSelectedBU;
    final storedSection = appState.powerUserSelectedSection;

    final shouldUpdate =
        (storedBU != null && storedBU.isNotEmpty && storedBU != selectedBU) ||
            (storedSection != null &&
                storedSection.isNotEmpty &&
                storedSection != selectedSection);

    if (shouldUpdate) {
      setState(() {
        if (storedBU != null && storedBU.isNotEmpty) {
          selectedBU = storedBU;
        }
        if (storedSection != null && storedSection.isNotEmpty) {
          selectedSection = storedSection;
        }
      });
      _fetchAssessmentsForPowerUser().then((_) => _loadAssessmentCounts());
    }
  }

  Future<void> _fetchAssessmentsForPowerUser() async {
    if (_isFetchingAssessments) return;
    _isFetchingAssessments = true;

    try {
      final appState = Provider.of<AppState>(context, listen: false);

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('company')
          .doc('main')
          .collection('users')
          .get();

      final List<SubmittedAssessment> tempAssessments = [];

      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final assessmentsArray =
            userData['assessments'] as List<dynamic>? ?? [];

        final userName = userData['name'] as String? ?? 'Unknown';
        final dynamic employeeIdRaw = userData['employeeId'];
        final int? employeeId = employeeIdRaw is int
            ? employeeIdRaw
            : int.tryParse(employeeIdRaw?.toString() ?? '');

        for (final assessmentData in assessmentsArray) {
          if (assessmentData is! Map) continue;

          final assessmentMap = Map<String, dynamic>.from(assessmentData);
          assessmentMap['userName'] = userName;
          assessmentMap['employeeId'] = employeeId;

          try {
            tempAssessments.add(SubmittedAssessment.fromJson(assessmentMap));
          } catch (_) {
            // Ignore corrupted entries
          }
        }
      }

      // Replace in-memory list (don't persist to disk; Firestore is source of truth)
      appState.assessments
        ..clear()
        ..addAll(tempAssessments);

      if (mounted) {
        setState(() {});
      }
    } finally {
      _isFetchingAssessments = false;
    }
  }

  Future<void> _loadAssessmentCounts() async {
    try {
      // Get all assessments
      final appState = Provider.of<AppState>(context, listen: false);
      final allAssessments = appState.assessments;

      // Filter based on selected BU and section if any
      var filteredAssessments = allAssessments.where((a) {
        final buMatch = selectedBU == 'All BUs' || a.bu == selectedBU;
        final sectionMatch =
            selectedSection == 'All Sections' || a.section == selectedSection;
        return buMatch && sectionMatch;
      }).toList();

      // Get passed and flagged counts
      final passedAssessments =
          filteredAssessments.where((a) => a.score >= 90).toList();
      final flaggedAssessments =
          filteredAssessments.where((a) => a.isFlagged).toList();

      // Calculate average score from all assessments with valid scores
      final validScores = filteredAssessments
          .where((a) => a.score != null)
          .map((a) => a.score)
          .toList();

      final averageScore = validScores.isEmpty
          ? 0.0
          : validScores.reduce((a, b) => a + b) / validScores.length;

      if (mounted) {
        setState(() {
          _totalAssessmentsCount = filteredAssessments.length;
          _passedAssessmentsCount = passedAssessments.length;
          _flaggedAssessmentsCount = flaggedAssessments.length;
          _averageScore = averageScore;
        });
      }

      final flaggedEmployeesCount = await _fetchFlaggedEmployeesCount();
      if (mounted) {
        setState(() {
          _flaggedEmployeesCount = flaggedEmployeesCount;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load assessment counts: $e')),
        );
      }
    }
  }

  Future<int> _fetchFlaggedEmployeesCount() async {
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('company')
        .doc('main')
        .collection('users')
        .get();

    final flaggedEmployeeIds = <String>{};

    for (final userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();

      final userBu = (userData['business_unit'] ?? userData['bu'])?.toString();
      final userSection = userData['section']?.toString();

      final buMatch = selectedBU == 'All BUs' || userBu == selectedBU;
      final sectionMatch =
          selectedSection == 'All Sections' || userSection == selectedSection;
      if (!buMatch || !sectionMatch) continue;

      final assessments = userData['assessments'];
      if (assessments is! List) continue;

      bool hasActiveFlag = false;
      for (final a in assessments) {
        if (a is! Map) continue;
        final aMap = Map<String, dynamic>.from(a);

        final isFlagged = aMap['isFlagged'] == true;
        final resolved = aMap['resolved'] == true;
        if (isFlagged && !resolved) {
          hasActiveFlag = true;
          break;
        }
      }

      if (hasActiveFlag) {
        flaggedEmployeeIds.add(userDoc.id);
      }
    }

    return flaggedEmployeeIds.length;
  }

  // Calculate scores for all BUs
  Map<String, double> _calculateAllBUScores() {
    final appState = Provider.of<AppState>(context, listen: false);
    final allAssessments = appState.assessments;

    final Map<String, double> buScores = {};

    // Define all BUs
    final List<String> allBUs = ['BUFC', 'BUCP', 'BUFP'];

    for (final bu in allBUs) {
      final buAssessments = allAssessments.where((a) => a.bu == bu).toList();

      if (buAssessments.isEmpty) {
        buScores[bu] = 0.0;
      } else {
        final validScores = buAssessments
            .where((a) => a.score != null)
            .map((a) => a.score)
            .toList();

        final averageScore = validScores.isEmpty
            ? 0.0
            : validScores.reduce((a, b) => a + b) / validScores.length;

        buScores[bu] = averageScore;
      }
    }

    return buScores;
  }

  // Build card showing scores for all BUs
  Widget _buildAllBUScoresCard() {
    final buScores = _calculateAllBUScores();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const Text(
            'All Business Units Scores',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // BUFC Score
              Expanded(
                child: _buildBUScoreItem(
                  'BUFC',
                  buScores['BUFC'] ?? 0.0,
                  const Color(0xFF059669),
                  Icons.business,
                ),
              ),
              const SizedBox(width: 12),
              // BUCP Score
              Expanded(
                child: _buildBUScoreItem(
                  'BUCP',
                  buScores['BUCP'] ?? 0.0,
                  const Color(0xFF0891B2),
                  Icons.business_center,
                ),
              ),
              const SizedBox(width: 12),
              // BUFP Score
              Expanded(
                child: _buildBUScoreItem(
                  'BUFP',
                  buScores['BUFP'] ?? 0.0,
                  const Color(0xFFDC2626),
                  Icons.factory,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build individual BU score item
  Widget _buildBUScoreItem(
      String buName, double score, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            buName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${score.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  final Map<String, List<String>> buSectionsMap = {
    'BUCP': [
      'Facial Tissue',
      'Non-Tissue',
      'Tissue Roll',
      'PM-09',
      'FemCare',
    ],
    'BUFC': [
      'Offset Printing',
      'FG& Paper Cup',
      'Roto Line',
    ],
    'BUFP': [
      'Printing',
      'Lamination',
      'Extrusion',
      'Slitting',
    ],
  };

  List<String> get currentSections =>
      ['All Sections', ...?buSectionsMap[selectedBU]];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Power User Dashboard'),
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              Routes.login,
              (route) => false,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUnifiedDateFilter(),
            const SizedBox(height: 16),
            _buildBUDropdown(),
            const SizedBox(height: 12),
            _buildSectionDropdown(),
            const SizedBox(height: 24),

            // BU Overall Score Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0891B2), Color(0xFF0EA5E9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0891B2).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '$selectedBU Overall Score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_averageScore.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Period: $filterPeriod',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            if (selectedSection != 'All Sections')
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0891B2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF0891B2).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.category_outlined,
                        color: Color(0xFF0891B2), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Section: $selectedSection',
                      style: const TextStyle(
                          color: Color(0xFF0891B2),
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () =>
                          setState(() => selectedSection = 'All Sections'),
                      child: const Icon(Icons.close,
                          size: 14, color: Color(0xFF0891B2)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // All BUs Scores Card
            _buildAllBUScoresCard(),

            const SizedBox(height: 24),
            // Quick Stats
            // In the build method, update the stat cards like this:
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Assessments',
                    _totalAssessmentsCount.toString(),
                    Icons.assignment,
                    const Color(0xFF059669),
                    onTap: () => Navigator.pushNamed(
                      context,
                      Routes.assessmentHistory,
                      arguments: {
                        'selectedBU': selectedBU,
                        'selectedSection': selectedSection,
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Flagged Assessments',
                    _flaggedAssessmentsCount.toString(),
                    Icons.error_outline,
                    const Color(0xFFDC2626),
                    onTap: () => Navigator.pushNamed(
                      context,
                      Routes.failedAudits,
                      arguments: {
                        'selectedBU': selectedBU,
                        'selectedSection': selectedSection,
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Flagged Employees',
                    _flaggedEmployeesCount.toString(),
                    Icons.flag_outlined,
                    const Color(0xFFEA580C),
                    onTap: () => Navigator.pushNamed(
                      context,
                      Routes.flaggedEmployees,
                      arguments: {
                        'selectedBU': selectedBU,
                        'selectedSection': selectedSection,
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Passed Assessments',
                    _passedAssessmentsCount.toString(),
                    Icons.check_circle_outline,
                    const Color(0xFF7C3AED),
                    onTap: () => Navigator.pushNamed(
                      context,
                      Routes.passedAssessments,
                      arguments: {
                        'selectedBU': selectedBU,
                        'selectedSection': selectedSection,
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            // Action Buttons
            Text(
              'Management Actions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 16),
            _buildActionButton(
              'Manage Questions',
              'Edit, add, or remove assessment questions',
              Icons.quiz_outlined,
              const Color(0xFF7C3AED),
              () => Navigator.pushNamed(context, Routes.manageQuestions),
            ),

            const SizedBox(height: 12),
            _buildActionButton(
              'View Previous Assessments',
              'Review historical assessment data',
              Icons.history,
              const Color(0xFF059669),
              () => Navigator.pushNamed(
                context,
                Routes.previousAssessments,
                arguments: {
                  'selectedBU': selectedBU,
                  'selectedSection': selectedSection,
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Failed Audits',
              'Review and manage failed audit cases',
              Icons.error_outline,
              const Color(0xFFDC2626),
              () => Navigator.pushNamed(
                context,
                Routes.failedAudits,
                arguments: {
                  'selectedBU': selectedBU,
                  'selectedSection': selectedSection,
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Flagged Employees',
              'Manage employees requiring attention',
              Icons.flag_outlined,
              const Color(0xFFEA580C),
              () => Navigator.pushNamed(
                context,
                Routes.flaggedEmployees,
                arguments: {
                  'selectedBU': selectedBU,
                  'selectedSection': selectedSection,
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              'Observations',
              'View remarks captured by auditors/auditees',
              Icons.comment_outlined,
              const Color(0xFF0891B2),
              () => Navigator.pushNamed(context, Routes.observations),
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              'Send Follow-up Emails',
              'Trigger follow-up emails for overdue assessments',
              Icons.email_outlined,
              const Color(0xFF7C3AED),
              () => FollowUpService.triggerManualFollowUpCheck(context),
            ),

          ],
        ),
      ),
    );
  }

  void _onBUChanged(String? newValue) {
    if (newValue != null) {
      setState(() {
        selectedBU = newValue;
        selectedSection = 'All Sections'; // Reset section when BU changes
      });
      final appState = Provider.of<AppState>(context, listen: false);
      appState.selectPowerUserBU(selectedBU);
      appState.selectPowerUserSection(selectedSection);
      _fetchAssessmentsForPowerUser().then((_) => _loadAssessmentCounts());
    }
  }

  void _onSectionChanged(String? newValue) {
    if (newValue != null) {
      setState(() {
        selectedSection = newValue;
      });
      final appState = Provider.of<AppState>(context, listen: false);
      appState.selectPowerUserBU(selectedBU);
      appState.selectPowerUserSection(selectedSection);
      _loadAssessmentCounts();
    }
  }

  Future<void> _testEmailConnection() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Testing email connection...'),
          backgroundColor: Color(0xFF0891B2),
          duration: Duration(seconds: 2),
        ),
      );

      final success = await EmailService.testEmailConnection();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Test email sent successfully!'
                : 'Test email failed. Check console for details.'),
            backgroundColor:
                success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test email error: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showEmailLog() {
    final emailLog = EmailService.getEmailLog();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.list_alt, color: Color(0xFF6366F1)),
              SizedBox(width: 8),
              Text('Email Log'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: emailLog.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No emails logged yet',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        Text(
                          'Send test emails or submit assessments to see logs',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: emailLog.length,
                    itemBuilder: (context, index) {
                      final log = emailLog.reversed
                          .toList()[index]; // Show newest first
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: log['type'] == 'test_email'
                                ? const Color(0xFF059669).withOpacity(0.1)
                                : log['type'] == 'assessment_email'
                                    ? const Color(0xFF0891B2).withOpacity(0.1)
                                    : const Color(0xFF7C3AED).withOpacity(0.1),
                            child: Icon(
                              log['type'] == 'test_email'
                                  ? Icons.email
                                  : log['type'] == 'assessment_email'
                                      ? Icons.assessment
                                      : Icons.email_outlined,
                              color: log['type'] == 'test_email'
                                  ? const Color(0xFF059669)
                                  : log['type'] == 'assessment_email'
                                      ? const Color(0xFF0891B2)
                                      : const Color(0xFF7C3AED),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            log['subject'] ?? 'No Subject',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('To: ${(log['to'] as List).join(', ')}'),
                              Text(
                                  'Time: ${DateTime.parse(log['timestamp']).toString().split('.')[0]}'),
                              if (log['simulation'] == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'SIMULATION',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: const Icon(Icons.check_circle,
                              color: Colors.green),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                EmailService.clearEmailLog();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email log cleared'),
                    backgroundColor: Color(0xFF6366F1),
                  ),
                );
              },
              child: const Text('Clear Log'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _exportEmailLog() {
    final emailLog = EmailService.exportEmailLog();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.download, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text('Export Email Log'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: SingleChildScrollView(
              child: SelectableText(
                emailLog,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Copy to clipboard
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email log copied to clipboard'),
                    backgroundColor: Color(0xFF7C3AED),
                  ),
                );
              },
              child: const Text('Copy to Clipboard'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBUDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.business, color: Color(0xFF0891B2)),
          const SizedBox(width: 8),
          const Text('Business Unit',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedBU,
                isExpanded: true,
                items: ['BUFC', 'BUCP', 'BUFP']
                    .map((bu) => DropdownMenuItem(value: bu, child: Text(bu)))
                    .toList(),
                onChanged: _onBUChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.category_outlined, color: Color(0xFF0891B2)),
          const SizedBox(width: 8),
          const Text('Section',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedSection,
                isExpanded: true,
                items: currentSections
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: _onSectionChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedDateFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_list, color: Color(0xFF0891B2)),
              SizedBox(width: 8),
              Text(
                'Filter by Date',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _chip('All Time', () {
                setState(() {
                  selectedDateRange = null;
                  filterPeriod = 'All Time';
                });
              }, isSelected: filterPeriod == 'All Time'),
              _chip('Last 7 Days', () {
                setState(() {
                  selectedDateRange = DateTimeRange(
                    start: DateTime.now().subtract(const Duration(days: 7)),
                    end: DateTime.now(),
                  );
                  filterPeriod = 'Last 7 Days';
                });
              }, isSelected: filterPeriod == 'Last 7 Days'),
              _chip('Last 30 Days', () {
                setState(() {
                  selectedDateRange = DateTimeRange(
                    start: DateTime.now().subtract(const Duration(days: 30)),
                    end: DateTime.now(),
                  );
                  filterPeriod = 'Last 30 Days';
                });
              }, isSelected: filterPeriod == 'Last 30 Days'),
              _customRangeChip(),
            ],
          ),
          if (selectedDateRange != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.date_range,
                    size: 16, color: Color(0xFF0891B2)),
                const SizedBox(width: 8),
                Text(
                  '${selectedDateRange!.start.day}/${selectedDateRange!.start.month}/${selectedDateRange!.start.year} - '
                  '${selectedDateRange!.end.day}/${selectedDateRange!.end.month}/${selectedDateRange!.end.year}',
                  style: const TextStyle(
                      color: Color(0xFF0891B2),
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedDateRange = null;
                      filterPeriod = 'All Time';
                    });
                  },
                  child: const Icon(Icons.close,
                      size: 16, color: Color(0xFF0891B2)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap, {bool isSelected = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0891B2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF0891B2)
                  : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _customRangeChip() {
    final isSelected = filterPeriod == 'Custom Range';

    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final initialStartDate =
            selectedDateRange?.start ?? now.subtract(const Duration(days: 30));
        final initialEndDate = selectedDateRange?.end ?? now;

        final DateTimeRange? picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: now,
          initialDateRange: DateTimeRange(
            start: initialStartDate,
            end: initialEndDate,
          ),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF0891B2),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF0F172A),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0891B2),
                  ),
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          setState(() {
            selectedDateRange = picked;
            filterPeriod = 'Custom Range';
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0891B2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0891B2) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          'Custom Range',
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF94A3B8),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
