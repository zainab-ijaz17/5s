import 'package:flutter/material.dart';

import '../../routes.dart';

import 'package:provider/provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../state/app_state.dart';

import '../models/submitted_assessment.dart';

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
  String selectedDateFilter = "All Time";

  String selectedSection = "All Sections";

  String buCode = '';

  String buName = '';

  int _attemptedCount = 0;
  int _passedCount = 0;
  int _failedCount = 0;
  bool _isLoadingCounts = false;
  bool _countsLoadedForBU = false;

  final List<SubmittedAssessment> _firestoreAssessments = [];
  bool _isLoadingAssessments = false;
  bool _assessmentsLoadedForBU = false;

  Future<void> _loadAssessmentsFromFirestore() async {
    if (_isLoadingAssessments) return;
    if (buCode.isEmpty) return;

    setState(() {
      _isLoadingAssessments = true;
    });

    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('company')
          .doc('main')
          .collection('users')
          .get();

      final List<SubmittedAssessment> tempAssessments = [];

      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final assessmentsArray = userData['assessments'];
        if (assessmentsArray is! List) continue;

        for (final a in assessmentsArray) {
          if (a is! Map) continue;
          final aMap = Map<String, dynamic>.from(a);
          if (aMap['bu']?.toString() != buCode) continue;

          try {
            tempAssessments.add(SubmittedAssessment.fromJson(aMap));
          } catch (_) {
            // Ignore corrupted entries
          }
        }
      }

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

  Future<void> _loadCountsFromFirestore() async {
    if (_isLoadingCounts) return;
    if (buCode.isEmpty) return;

    setState(() {
      _isLoadingCounts = true;
    });

    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('company')
          .doc('main')
          .collection('users')
          .get();

      int attempted = 0;
      int passed = 0;
      int failed = 0;

      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final assessmentsArray = userData['assessments'];
        if (assessmentsArray is! List) continue;

        for (final a in assessmentsArray) {
          if (a is! Map) continue;
          final aMap = Map<String, dynamic>.from(a);

          final bu = aMap['bu']?.toString();
          if (bu != buCode) continue;

          attempted++;

          final bool isFlagged = aMap['isFlagged'] == true;
          final bool resolved = aMap['resolved'] == true;

          if (isFlagged && !resolved) {
            failed++;
          } else {
            passed++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _attemptedCount = attempted;
          _passedCount = passed;
          _failedCount = failed;
          _countsLoadedForBU = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCounts = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get BU information from route arguments

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, String>?;

    if (args != null) {
      setState(() {
        buCode = args['buCode'] ?? '';

        buName = args['buName'] ?? '';
      });
    }

    if (!_countsLoadedForBU && buCode.isNotEmpty) {
      _loadCountsFromFirestore();
    }

    if (!_assessmentsLoadedForBU && buCode.isNotEmpty) {
      _loadAssessmentsFromFirestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    final List<SubmittedAssessment> effectiveAssessments =
        _assessmentsLoadedForBU ? _firestoreAssessments : appState.assessments;

    final List<SubmittedAssessment> allAssessments =
        effectiveAssessments.toList().reversed.toList();

    // Filter assessments for the selected BU only

    final List<SubmittedAssessment> buAllAssessments = allAssessments;

    final List<SubmittedAssessment> failedAssessments =
        buAllAssessments.where((a) => a.isFlagged && !a.resolved).toList();

    // Calculate real BU statistics from actual assessment data

    final Map<String, List<SubmittedAssessment>> buAssessments = {};

    for (final assessment in allAssessments) {
      final bu = assessment.bu ?? 'Unknown';

      buAssessments.putIfAbsent(bu, () => []).add(assessment);
    }

    // Update business units with real data

    final List<Map<String, dynamic>> realBusinessUnits = [];

    buAssessments.forEach((bu, assessments) {
      final passedCount =
          assessments.where((a) => !a.isFlagged || a.resolved).length;

      final totalCount = assessments.length;

      final completionRate =
          totalCount > 0 ? ((passedCount / totalCount) * 100).round() : 0;

      final flaggedCount =
          assessments.where((a) => a.isFlagged && !a.resolved).length;

      realBusinessUnits.add({
        'shortName': bu,

        'fullName': bu, // Use BU name as full name for now

        'completionRate': completionRate,

        'flagged': flaggedCount,

        'sections': assessments
            .map((a) => a.section)
            .where((s) => s != null)
            .toSet()
            .toList(),

        'assessments': totalCount,
      });
    });

    // Filter to show only the selected BU

    Map<String, dynamic> selectedBUData;

    if (buCode.isNotEmpty && realBusinessUnits.isNotEmpty) {
      // Try to find the selected BU in real data

      selectedBUData = realBusinessUnits.firstWhere(
        (bu) => bu['shortName'] == buCode,
        orElse: () => {
          // Create empty data for selected BU if no assessments exist yet

          'shortName': buCode,

          'fullName': buName,

          'completionRate': 0,

          'flagged': 0,

          'sections': <String>[],

          'assessments': 0,
        },
      );
    } else {
      selectedBUData = {
        'shortName': buCode.isNotEmpty ? buCode : 'BU',
        'fullName': buName.isNotEmpty
            ? buName
            : (buCode.isNotEmpty ? buCode : 'Business Unit'),
        'completionRate': 0,
        'flagged': 0,
        'sections': <String>[],
        'assessments': 0,
      };
    }

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
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
          children: [
            const SizedBox.shrink(),

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
                    "Filter: $selectedDateFilter",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const SizedBox.shrink(),

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
                          selectedBUData['fullName'],
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
                            _isLoadingCounts ? '...' : '$_attemptedCount'),
                        _metricTile('Passed',
                            _isLoadingCounts ? '...' : '$_passedCount'),
                        _metricTile('Failed',
                            _isLoadingCounts ? '...' : '$_failedCount'),
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
              const Center(child: CircularProgressIndicator())
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
              const Center(child: CircularProgressIndicator())
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

  Widget _buildDateFilter(BuildContext context) {
    return DropdownButton<String>(
      value: selectedDateFilter,
      items: ["All Time", "Last 7 Days", "Last 30 Days", "Custom"]
          .map((filter) => DropdownMenuItem(value: filter, child: Text(filter)))
          .toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() => selectedDateFilter = val);
        }
      },
    );
  }

  Widget _buildSectionFilter(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final allSectionsFromData = appState.assessments
        .where((a) => buCode.isEmpty || (a.bu ?? '') == buCode)
        .map((a) => a.section)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    List<String> allSections = [
      "All Sections",
      ...allSectionsFromData,
    ];

    return DropdownButton<String>(
      value: selectedSection,
      items: allSections
          .map((section) =>
              DropdownMenuItem(value: section, child: Text(section)))
          .toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() => selectedSection = val);
        }
      },
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
