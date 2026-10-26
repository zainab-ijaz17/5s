import 'package:flutter/material.dart';

import '../../routes.dart';
import '../widgets/role_bottom_nav.dart';
import '../navigation/role_section.dart';
import '../services/assessment_service.dart';
import '../services/session_service.dart';

import 'package:provider/provider.dart';

import '../state/app_state.dart';

import '../models/submitted_assessment.dart';
import '../widgets/loading_overlay.dart';

/// ----------------------

/// BU MANAGER DASHBOARD

/// ----------------------

class BUManagerDashboardScreen extends StatefulWidget {
  const BUManagerDashboardScreen({super.key});

  @override
  State<BUManagerDashboardScreen> createState() =>
      _BUManagerDashboardScreenState();
}

class _BUManagerDashboardScreenState extends State<BUManagerDashboardScreen> {
  String selectedSection = 'All Sections';
  DateTimeRange? selectedDateRange;
  String filterPeriod = 'All Time';

  String buCode = '';
  String buName = '';

  final List<SubmittedAssessment> _firestoreAssessments = [];
  bool _isLoadingAssessments = false;
  bool _assessmentsLoadedForBU = false;
  final AssessmentService _assessmentService = AssessmentService();

  static const Map<String, List<String>> buSectionsMap = {
    'BUCP': [
      'Facial Tissue',
      'Non-Tissue',
      'Tissue Roll',
      'PM-09',
      'FemCare',
    ],
    'BUFC': [
      'Folding & Gluing',
      'Offset Printing',
      'Roto Line',
      'Sorting & Breaking',
      'FG& paper Cup',
    ],
    'BUFP': [
      'Printing',
      'Lamination',
      'Extrusion',
      'Slitting',
      'Mechanical Workshop',
      'Electrical Workshop',
    ],
  };

  List<String> get currentSections {
    final predefined = buSectionsMap[buCode];
    if (predefined != null) {
      return ['All Sections', ...predefined];
    }
    final fromData = _firestoreAssessments
        .map((a) => a.section)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All Sections', ...fromData];
  }

  bool _matchesDateFilter(DateTime date) {
    if (selectedDateRange == null) return true;
    final start = DateTime(
      selectedDateRange!.start.year,
      selectedDateRange!.start.month,
      selectedDateRange!.start.day,
    );
    final end = DateTime(
      selectedDateRange!.end.year,
      selectedDateRange!.end.month,
      selectedDateRange!.end.day,
      23,
      59,
      59,
    );
    return !date.isBefore(start) && !date.isAfter(end);
  }

  bool _matchesFilters(SubmittedAssessment assessment) {
    if (buCode.isNotEmpty && assessment.bu != buCode) return false;
    if (selectedSection != 'All Sections' &&
        assessment.section != selectedSection) {
      return false;
    }
    return _matchesDateFilter(assessment.date);
  }

  List<SubmittedAssessment> _filterAssessments(
    List<SubmittedAssessment> source,
  ) {
    return source.where(_matchesFilters).toList();
  }

  Future<void> _loadAssessmentsFromBackend() async {
    if (_isLoadingAssessments) return;
    if (buCode.isEmpty) return;

    setState(() {
      _isLoadingAssessments = true;
    });

    try {
      final all = await _assessmentService.getAllAssessments();
      final tempAssessments = all.where((a) => a.bu == buCode).toList();

      if (mounted) {
        setState(() {
          _firestoreAssessments
            ..clear()
            ..addAll(tempAssessments);
          _assessmentsLoadedForBU = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAssessments = false;
        });
      }
    }
  }

  Future<void> _goBackToBuSelection(
    BuildContext context,
    AppState appState,
  ) async {
    // Replacement navigation leaves no stack to pop — always return to BU picker.
    await SessionService.instance.saveAssessmentContext(
      auditor: appState.auditorName,
      auditee: appState.auditeeName,
      company: appState.selectedCompany,
      bu: null,
      section: null,
      lastRoute: Routes.buSelection,
    );
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, Routes.buSelection);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, String>?;

    if (args != null) {
      setState(() {
        buCode = args['buCode'] ?? '';
        buName = args['buName'] ?? '';
      });
    }

    if (!_assessmentsLoadedForBU && buCode.isNotEmpty) {
      _loadAssessmentsFromBackend();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    final List<SubmittedAssessment> effectiveAssessments =
        _assessmentsLoadedForBU ? _firestoreAssessments : appState.assessments;

    final List<SubmittedAssessment> allAssessments =
        effectiveAssessments.toList().reversed.toList();

    final buScoped = buCode.isEmpty
        ? allAssessments
        : allAssessments.where((a) => a.bu == buCode).toList();

    final List<SubmittedAssessment> buAllAssessments =
        _filterAssessments(buScoped);

    final List<SubmittedAssessment> failedAssessments = buAllAssessments
        .where((a) => a.isFlagged && !a.resolved)
        .toList();

    final attemptedCount = buAllAssessments.length;
    final passedCount = buAllAssessments
        .where((a) => !a.isFlagged || a.resolved)
        .length;
    final failedCount = failedAssessments.length;
    final completionRate = attemptedCount > 0
        ? ((passedCount / attemptedCount) * 100).round()
        : 0;
    final averageScore = attemptedCount == 0
        ? 0.0
        : buAllAssessments.map((a) => a.score).reduce((a, b) => a + b) /
            attemptedCount;

    final selectedBUData = {
      'shortName': buCode.isNotEmpty ? buCode : 'BU',
      'fullName': buName.isNotEmpty
          ? buName
          : (buCode.isNotEmpty ? buCode : 'Business Unit'),
      'completionRate': completionRate,
      'flagged': failedCount,
      'sections': buAllAssessments
          .map((a) => a.section)
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList(),
      'assessments': attemptedCount,
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          buName.isNotEmpty ? '$buCode Dashboard' : 'BU Manager Dashboard',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Change Business Unit',
          onPressed: () => _goBackToBuSelection(context, appState),
        ),
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
            const SizedBox(height: 12),
            _buildSectionDropdown(),
            if (selectedSection != 'All Sections') ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0891B2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF0891B2).withOpacity(0.3),
                  ),
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
                        fontWeight: FontWeight.w500,
                      ),
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
            ],
            const SizedBox(height: 16),

            /// ----------------- HEADER CARD -----------------

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0891B2), Color(0xFF0EA5E9)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0891B2).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.dashboard, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    buName.isNotEmpty
                        ? buName
                        : (buCode.isNotEmpty ? buCode : 'BU Manager'),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Period: $filterPeriod',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// ----------------- SCORE CARD (selected BU) -----------------
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
                    '${buCode.isNotEmpty ? buCode : 'BU'} Overall Score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (selectedSection != 'All Sections') ...[
                    const SizedBox(height: 6),
                    Text(
                      'Section: $selectedSection',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    _isLoadingAssessments && !_assessmentsLoadedForBU
                        ? '...'
                        : '${averageScore.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Period: $filterPeriod',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  if (!_isLoadingAssessments || _assessmentsLoadedForBU) ...[
                    const SizedBox(height: 8),
                    Text(
                      attemptedCount == 0
                          ? 'No assessments in this filter'
                          : 'Based on $attemptedCount assessment${attemptedCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                buCode.isNotEmpty ? '$buCode Analytics' : 'BU Analytics',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics, color: Color(0xFF0891B2)),
                        const SizedBox(width: 8),
                        Text(
                          selectedBUData['fullName'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _metricTile('Attempted',
                            _isLoadingAssessments ? '...' : '$attemptedCount'),
                        _metricTile('Passed',
                            _isLoadingAssessments ? '...' : '$passedCount'),
                        _metricTile('Failed',
                            _isLoadingAssessments ? '...' : '$failedCount'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (selectedBUData['completionRate'] as int) / 100,
                      color: (selectedBUData['completionRate'] as int) >= 80
                          ? Colors.green
                          : (selectedBUData['completionRate'] as int) >= 60
                              ? Colors.amber
                              : Colors.red,
                      backgroundColor: Colors.grey[200],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // All Assessments Section

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "All Attempted Assessments",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (_isLoadingAssessments && !_assessmentsLoadedForBU)
              const Center(
                child: LoadingPanel(message: 'Loading assessments...'),
              )
            else if (buAllAssessments.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        buCode.isNotEmpty
                            ? "No assessments have been attempted for $buCode yet."
                            : "No assessments have been attempted yet.",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 400, // Constrain height to prevent overflow

                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: buAllAssessments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final sa = buAllAssessments[index];

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
                        leading: CircleAvatar(
                          backgroundColor: sa.resolved
                              ? const Color(0xFF10B981).withOpacity(0.1)
                              : sa.isFlagged
                                  ? const Color(0xFFEF4444).withOpacity(0.1)
                                  : const Color(0xFF10B981).withOpacity(0.1),
                          child: Icon(
                            sa.resolved
                                ? Icons.verified
                                : sa.isFlagged
                                    ? Icons.flag
                                    : Icons.check_circle,
                            color: sa.resolved
                                ? const Color(0xFF10B981)
                                : sa.isFlagged
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '${sa.bu ?? sa.company} (${sa.score}%)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                                'Date: ${sa.date.toString().split(' ').first}'),
                            Text('Auditor: ${sa.auditorName}'),
                            Text('Auditee: ${sa.auditeeName}'),
                            if (sa.section != null)
                              Text('Section: ${sa.section}'),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: sa.resolved
                                    ? const Color(0xFF10B981).withOpacity(0.1)
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
                        trailing: TextButton(
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
                                'resolvedAt': sa.resolvedAt?.toIso8601String(),
                                'resolvedBy': sa.resolvedBy,
                              },
                            );
                          },
                          child: const Text('View'),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Failed Assessments",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (_isLoadingAssessments && !_assessmentsLoadedForBU)
              const Center(
                child: LoadingPanel(message: 'Loading assessments...'),
              )
            else if (failedAssessments.isEmpty)
              Text(
                buCode.isNotEmpty
                    ? "No failed assessments for $buCode."
                    : "No failed assessments.",
                style: const TextStyle(color: Colors.grey),
              )
            else
              SizedBox(
                height: 300, // Constrain height to prevent overflow

                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: failedAssessments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final sa = failedAssessments[index];

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
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                          ],
                        ),
                        trailing: TextButton(
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
                                'resolvedAt': sa.resolvedAt?.toIso8601String(),
                                'resolvedBy': sa.resolvedBy,
                              },
                            );
                          },
                          child: const Text('View'),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: const RoleBottomNav(current: RoleSection.buDashboard),
    );
  }

  Widget _metricTile(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _onSectionChanged(String? newValue) {
    if (newValue == null) return;
    setState(() => selectedSection = newValue);
  }

  Widget _buildSectionDropdown() {
    final sections = currentSections;
    final value =
        sections.contains(selectedSection) ? selectedSection : 'All Sections';

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
          Expanded(
            child: Text(
              buCode.isNotEmpty ? '$buCode Section' : 'Section',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: sections
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
                    fontWeight: FontWeight.w500,
                  ),
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
                : const Color(0xFFE2E8F0),
          ),
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

  Widget _buildActionCard(
      BuildContext context, IconData icon, String title, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        width: (MediaQuery.of(context).size.width - 48) / 2,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            Icon(icon, size: 32, color: const Color(0xFF0891B2)),
            const SizedBox(height: 8),
            Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessUnitCard(Map<String, dynamic> bu) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(bu['shortName'],
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (bu['flagged'] > 0)
                  Chip(
                    label: Text("${bu['flagged']} flagged",
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.red,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(bu['fullName'],
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: bu['sections']
                  .map<Widget>((s) =>
                      Chip(label: Text(s), backgroundColor: Colors.blue[50]))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: bu['completionRate'] / 100,
                    color: bu['completionRate'] >= 80
                        ? Colors.green
                        : bu['completionRate'] >= 60
                            ? Colors.amber
                            : Colors.red,
                    backgroundColor: Colors.grey[200],
                  ),
                ),
                const SizedBox(width: 12),
                Text("${bu['completionRate']}%"),
              ],
            ),
            const SizedBox(height: 8),
            Text("Assessments: ${bu['assessments']}"),
          ],
        ),
      ),
    );
  }
}
