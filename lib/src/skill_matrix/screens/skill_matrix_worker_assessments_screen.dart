import 'package:flutter/material.dart';

import '../models/skill_matrix_models.dart';
import '../services/skill_matrix_api_service.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_assessment_card.dart';
import '../widgets/skill_matrix_widgets.dart';

class SkillMatrixWorkerAssessmentsScreen extends StatefulWidget {
  const SkillMatrixWorkerAssessmentsScreen({super.key});

  @override
  State<SkillMatrixWorkerAssessmentsScreen> createState() =>
      _SkillMatrixWorkerAssessmentsScreenState();
}

class _SkillMatrixWorkerAssessmentsScreenState
    extends State<SkillMatrixWorkerAssessmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  String? _error;
  List<SkillMatrixSkillRow> _selfRows = [];
  List<SkillMatrixSkillRow> _managerRows = [];
  bool _showManager = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final selfRows = await SkillMatrixApiService.instance.fetchCurrentLines();
      final validated =
          await SkillMatrixApiService.instance.fetchValidatedForWorker();
      if (!mounted) return;
      setState(() {
        _selfRows = selfRows;
        _showManager = validated.showManagerView;
        _managerRows = validated.lines;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _selfRows = [];
        _managerRows = [];
        _showManager = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SkillMatrixTheme.scaffoldTop,
      appBar: AppBar(
        title: const Text('My assessments'),
        backgroundColor: SkillMatrixTheme.brandPrimary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'My self-ratings'),
            Tab(text: 'Manager validation'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: SkillMatrixTheme.brandPrimary),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load assessments.\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: SkillMatrixTheme.slate),
                    ),
                  ),
                )
              : TabBarView(
              controller: _tabs,
              children: [
                _list(_selfRows, 'Your submitted self-assessment lines.'),
                _showManager
                    ? _list(
                        _managerRows,
                        'Ratings validated by your line manager.',
                        showManager: true,
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Manager validation will appear here after your '
                            'assessment is submitted and reviewed.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: SkillMatrixTheme.slate, height: 1.4),
                          ),
                        ),
                      ),
              ],
            ),
    );
  }

  Widget _list(
    List<SkillMatrixSkillRow> rows,
    String subtitle, {
    bool showManager = false,
  }) {
    return SkillMatrixPageBackground(
      child: RefreshIndicator(
        color: SkillMatrixTheme.brandPrimary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: SkillMatrixTheme.slate,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const Text('No skills in this view yet.')
            else
              for (final row in rows) ...[
                SkillMatrixAssessmentCard(
                  row: row,
                  showManagerRating: showManager,
                ),
                if (showManager &&
                    row.managerComment != null &&
                    row.managerComment!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4, bottom: 8),
                    child: Text(
                      'Manager: ${row.managerComment}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: SkillMatrixTheme.slate,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}
