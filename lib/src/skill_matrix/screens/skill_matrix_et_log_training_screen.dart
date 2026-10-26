import 'package:flutter/material.dart';

import '../models/skill_matrix_user_profile.dart';
import '../services/skill_matrix_api_service.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_widgets.dart';

/// E&amp;T Admin · Log Training Session — assign trainings to workers (HTML reference).
class SkillMatrixEtLogTrainingScreen extends StatefulWidget {
  const SkillMatrixEtLogTrainingScreen({super.key});

  @override
  State<SkillMatrixEtLogTrainingScreen> createState() =>
      _SkillMatrixEtLogTrainingScreenState();
}

class _SkillMatrixEtLogTrainingScreenState
    extends State<SkillMatrixEtLogTrainingScreen> {
  bool _loading = true;
  bool _saving = false;
  List<SkillMatrixUserProfile> _workers = [];
  List<Map<String, dynamic>> _trainings = [];
  List<SkillMatrixAdminSkill> _skills = [];

  String? _workerId;
  String? _trainingId;
  String? _skillId;
  final _dueController = TextEditingController();
  final _newTrainingController = TextEditingController();
  final _hoursController = TextEditingController(text: '4');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _dueController.dispose();
    _newTrainingController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await SkillMatrixApiService.instance.fetchAdminUsers();
      _workers = users.where((u) => u.roleName == 'Worker').toList();
      _trainings = await SkillMatrixApiService.instance.fetchTrainingCatalog();
      _skills = await SkillMatrixApiService.instance.fetchAdminSkills();
      _workerId ??= _workers.isNotEmpty ? _workers.first.id : null;
      _trainingId ??= _trainings.isNotEmpty ? _trainings.first['id']?.toString() : null;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: 'Training due date',
    );
    if (picked != null) {
      _dueController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _assign() async {
    if (_workerId == null || _trainingId == null) return;
    setState(() => _saving = true);
    try {
      await SkillMatrixApiService.instance.assignTrainingToWorker(
        workerId: _workerId!,
        trainingId: _trainingId!,
        skillId: _skillId,
        dueDate: _dueController.text.trim().isEmpty
            ? null
            : _dueController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Training assigned to worker')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addTrainingToCatalog() async {
    final name = _newTrainingController.text.trim();
    if (name.isEmpty) return;
    final hours = double.tryParse(_hoursController.text.trim());
    await SkillMatrixApiService.instance.createTraining(
      name: name,
      durationHours: hours,
    );
    _newTrainingController.clear();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Training added to catalog')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SkillMatrixTheme.brandPrimary),
      );
    }

    return SkillMatrixPageBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const SkillMatrixHeroHeader(
            title: 'Log Training Session',
            subtitle: 'E & T Admin · assign development to close skill gaps',
            badge: 'Assignment',
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a worker and training program. Optionally link to a '
            'competency gap. Workers see assignments under Gaps & Trainings.',
            style: TextStyle(
              fontSize: 13.5,
              color: SkillMatrixTheme.slate,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          SkillMatrixSectionCard(
            title: 'Assign training',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SkillMatrixFieldLabel('Worker'),
                _dropdown(
                  value: _workerId,
                  items: _workers
                      .map(
                        (w) => DropdownMenuItem(
                          value: w.id,
                          child: Text(
                            '${w.fullName} (${w.employeeNumber})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _workerId = v),
                ),
                const SizedBox(height: 14),
                const SkillMatrixFieldLabel('Training program'),
                _dropdown(
                  value: _trainingId,
                  items: _trainings
                      .map(
                        (t) => DropdownMenuItem(
                          value: t['id']?.toString(),
                          child: Text(
                            t['name']?.toString() ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _trainingId = v),
                ),
                const SizedBox(height: 14),
                const SkillMatrixFieldLabel('Linked skill (optional)'),
                _dropdown(
                  value: _skillId,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— None —'),
                    ),
                    ..._skills.map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          '${s.categoryName} · ${s.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _skillId = v),
                ),
                const SizedBox(height: 14),
                const SkillMatrixFieldLabel('Due date'),
                TextField(
                  controller: _dueController,
                  readOnly: true,
                  onTap: _pickDueDate,
                  decoration: skillMatrixInputDecoration(hint: 'Tap to pick date').copyWith(
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                SkillMatrixPrimaryButton(
                  label: 'Assign to worker',
                  icon: Icons.send_rounded,
                  loading: _saving,
                  onPressed: _assign,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SkillMatrixSectionCard(
            title: 'Add training to catalog',
            subtitle: 'New programs available for assignment',
            child: Column(
              children: [
                TextField(
                  controller: _newTrainingController,
                  decoration: skillMatrixInputDecoration(label: 'Training name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hoursController,
                  keyboardType: TextInputType.number,
                  decoration: skillMatrixInputDecoration(label: 'Duration (hours)'),
                ),
                const SizedBox(height: 14),
                SkillMatrixPrimaryButton(
                  label: 'Add to catalog',
                  icon: Icons.playlist_add_rounded,
                  onPressed: _addTrainingToCatalog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: items.any((i) => i.value == value) ? value : null,
      isExpanded: true,
      decoration: skillMatrixInputDecoration(),
      items: items,
      onChanged: onChanged,
    );
  }
}
