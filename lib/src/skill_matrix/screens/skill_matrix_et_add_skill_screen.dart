import 'package:flutter/material.dart';

import '../models/skill_rating_level.dart';
import '../services/skill_matrix_api_service.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_widgets.dart';

class SkillMatrixEtAddSkillScreen extends StatefulWidget {
  const SkillMatrixEtAddSkillScreen({super.key});

  @override
  State<SkillMatrixEtAddSkillScreen> createState() =>
      _SkillMatrixEtAddSkillScreenState();
}

class _SkillMatrixEtAddSkillScreenState extends State<SkillMatrixEtAddSkillScreen> {
  final _nameController = TextEditingController();
  final _departmentController = TextEditingController(text: 'CPP');
  final _areaController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _loadingMeta = true;
  bool _saving = false;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _levels = [];
  String? _categoryId;
  final Set<String> _selectedLevelIds = {};
  int _defaultRequired = 3;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _departmentController.dispose();
    _areaController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    try {
      _categories = await SkillMatrixApiService.instance.fetchMasterCategories();
      _levels = await SkillMatrixApiService.instance.fetchMasterLevels();
      if (_categories.isNotEmpty) {
        _categoryId = _categories.first['id']?.toString();
      }
      if (_levels.isNotEmpty) {
        _selectedLevelIds.add(_levels.first['id']!.toString());
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingMeta = false);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _categoryId == null || _selectedLevelIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, category, and at least one level are required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await SkillMatrixApiService.instance.createSkill(
        name: name,
        categoryId: _categoryId!,
        department: _departmentController.text.trim(),
        area: _areaController.text.trim(),
        description: _descriptionController.text.trim(),
        applicableLevelIds: _selectedLevelIds.toList(),
        defaultRequiredLevel: _defaultRequired,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SkillMatrixTheme.scaffoldTop,
      appBar: AppBar(
        title: const Text('Add skill'),
        backgroundColor: SkillMatrixTheme.brandPrimary,
        foregroundColor: Colors.white,
      ),
      body: _loadingMeta
          ? const Center(
              child: CircularProgressIndicator(color: SkillMatrixTheme.brandPrimary),
            )
          : SkillMatrixPageBackground(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  const Text(
                    'Add a competency to the catalog. Workers only see skills '
                    'that apply to their operator level.',
                    style: TextStyle(
                      color: SkillMatrixTheme.slate,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SkillMatrixSectionCard(
                    title: 'Skill details',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SkillMatrixFieldLabel('Skill name'),
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: skillMatrixInputDecoration(
                            hint: 'e.g. Edge drop control',
                          ),
                        ),
                        const SizedBox(height: 14),
                        const SkillMatrixFieldLabel('Category'),
                        DropdownButtonFormField<String>(
                          value: _categoryId,
                          isExpanded: true,
                          decoration: skillMatrixInputDecoration(),
                          items: _categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c['id']?.toString(),
                                  child: Text(
                                    c['name']?.toString() ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _categoryId = v),
                        ),
                        const SizedBox(height: 14),
                        const SkillMatrixFieldLabel('Department'),
                        TextField(
                          controller: _departmentController,
                          decoration: skillMatrixInputDecoration(hint: 'CPP'),
                        ),
                        const SizedBox(height: 14),
                        const SkillMatrixFieldLabel('Area / line'),
                        TextField(
                          controller: _areaController,
                          decoration: skillMatrixInputDecoration(hint: 'Line 3'),
                        ),
                        const SizedBox(height: 14),
                        const SkillMatrixFieldLabel('Description'),
                        TextField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: skillMatrixInputDecoration(
                            hint: 'What this competency covers…',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SkillMatrixSectionCard(
                    title: 'Applicable levels',
                    subtitle: 'Select every operator level that must assess this skill',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final level in _levels)
                          FilterChip(
                            label: Text(level['code']?.toString() ?? ''),
                            selected: _selectedLevelIds.contains(level['id']?.toString()),
                            onSelected: (on) {
                              setState(() {
                                final id = level['id']!.toString();
                                if (on) {
                                  _selectedLevelIds.add(id);
                                } else if (_selectedLevelIds.length > 1) {
                                  _selectedLevelIds.remove(id);
                                }
                              });
                            },
                            selectedColor: SkillMatrixTheme.brandTint,
                            checkmarkColor: SkillMatrixTheme.brandPrimary,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SkillMatrixSectionCard(
                    title: 'Required proficiency',
                    subtitle: 'Default target (1–5) for selected levels',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Slider(
                          value: _defaultRequired.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: '$_defaultRequired',
                          activeColor: SkillMatrixTheme.brandPrimary,
                          onChanged: (v) => setState(() => _defaultRequired = v.round()),
                        ),
                        Text(
                          '${SkillRatingLevel.displayFor(_defaultRequired)} required for each applicable operator level',
                          style: const TextStyle(
                            fontSize: 13,
                            color: SkillMatrixTheme.slate,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SkillMatrixPrimaryButton(
                    label: 'Save skill',
                    icon: Icons.check_rounded,
                    loading: _saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
    );
  }
}
