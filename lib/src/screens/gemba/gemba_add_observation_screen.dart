import 'dart:io';
import '../../theme/gemba_colors.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/gemba_demo_data.dart';
import '../../data/gemba_org_data.dart';
import '../../models/gemba_employee.dart';
import '../../models/gemba_observation.dart';
import '../../models/gemba_observation_status.dart';
import '../../services/gemba_auth_service.dart';
import '../../services/gemba_observation_photos.dart';
import '../../services/gemba_observations_service.dart';
import '../../services/gemba_session_service.dart';
import '../../widgets/gemba_feedback.dart';
import '../../widgets/gemba_searchable_picker.dart';

class _ObservationDraftEntry {
  const _ObservationDraftEntry({
    required this.photo,
    required this.category,
    required this.remarks,
    required this.assignedEmployeeNumber,
    this.assignedEmployeeName,
  });

  final XFile photo;
  final String category;
  final String remarks;
  final String assignedEmployeeNumber;
  final String? assignedEmployeeName;
}

/// 2-step Gemba observation form:
/// 1) Location context · 2) Repeatable image + category + remarks + assignee entries
class GembaAddObservationScreen extends StatefulWidget {
  const GembaAddObservationScreen({
    super.key,
    this.onObservationSubmitted,
  });

  final VoidCallback? onObservationSubmitted;

  @override
  State<GembaAddObservationScreen> createState() =>
      _GembaAddObservationScreenState();
}

class _GembaAddObservationScreenState extends State<GembaAddObservationScreen> {
  
  

  final _entryRemarksController = TextEditingController();
  final _picker = ImagePicker();
  final _pageController = PageController();
  final _gembaAuth = GembaAuthService();

  int _step = 0;
  String _company = GembaOrgData.companies.first;
  String? _bu;
  String? _section;
  String? _machineValue;

  XFile? _draftPhoto;
  String? _draftCategory;
  String? _draftEmployeeNumber;
  final List<_ObservationDraftEntry> _savedEntries = [];

  List<GembaEmployee> _employees = const [];
  bool _employeesLoading = false;
  String? _employeesError;
  bool _saving = false;

  static const _stepMeta = [
    (title: 'Details', subtitle: 'Location', icon: Icons.tune_rounded),
    (
      title: 'Observations',
      subtitle: 'Add findings',
      icon: Icons.add_a_photo_outlined,
    ),
  ];

  bool get _isPcl => _company == 'Packages Convertors Limited';
  bool get _isTriPack => _company == 'Tri-Pack';

  List<String> get _sections {
    if (!_isPcl || _bu == null) return const [];
    return GembaOrgData.pclBuSections[_bu!] ?? const [];
  }

  List<GembaMachine> get _machines =>
      GembaOrgData.machinesForBuSection(_bu, _section);

  bool get _showMachine => _machines.isNotEmpty;

  List<GembaPickerOption> get _companyOptions => [
        for (final c in GembaOrgData.companies)
          GembaPickerOption(value: c, title: c),
      ];

  List<GembaPickerOption> get _pclBuOptions => [
        for (final bu in GembaOrgData.pclBuSections.keys)
          GembaPickerOption(
            value: bu,
            title: bu,
            subtitle: _buSubtitle(bu),
          ),
      ];

  List<GembaPickerOption> get _tripackBuOptions => [
        for (final bu in GembaOrgData.tripackBusinessUnits)
          GembaPickerOption(value: bu, title: bu),
      ];

  List<GembaPickerOption> get _sectionOptions => [
        for (final s in _sections) GembaPickerOption(value: s, title: s),
      ];

  List<GembaPickerOption> get _machineOptions => [
        for (final m in _machines)
          GembaPickerOption(
            value: m.value,
            title: '${m.code}-${m.name}',
          ),
      ];

  List<GembaPickerOption> get _categoryOptions => [
        for (final c in GembaOrgData.observationCategories)
          GembaPickerOption(value: c, title: c),
      ];

  List<GembaPickerOption> get _employeeOptions => [
        for (final e in _employees)
          GembaPickerOption(
            value: e.employeeNumber,
            title: e.employeeNumber,
            subtitle: (e.name == null || e.name!.trim().isEmpty)
                ? null
                : e.name!.trim(),
          ),
      ];

  String _buSubtitle(String bu) {
    switch (bu) {
      case 'BUFP':
        return 'Flexible Packaging';
      case 'BUFC':
        return 'Finished Goods Converters';
      case 'BUCP':
        return 'Consumer Products';
      default:
        return 'Business unit';
    }
  }

  @override
  void dispose() {
    _entryRemarksController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onCompanyChanged(String value) {
    setState(() {
      _company = value;
      _bu = null;
      _section = null;
      _machineValue = null;
      _draftEmployeeNumber = null;
      _employees = const [];
      _employeesError = null;
    });
  }

  void _onBuChanged(String value) {
    setState(() {
      _bu = value;
      _section = null;
      _machineValue = null;
      _draftEmployeeNumber = null;
      _employees = const [];
      _employeesError = null;
    });
  }

  void _onSectionChanged(String value) {
    setState(() {
      _section = value;
      _machineValue = null;
    });
  }

  bool _validateStep0() {
    if (_isPcl) {
      if (_bu == null || _bu!.isEmpty) {
        GembaFeedback.showError(context, 'Select a business unit');
        return false;
      }
      if (_section == null || _section!.isEmpty) {
        GembaFeedback.showError(context, 'Select a section');
        return false;
      }
    } else if (_isTriPack && (_bu == null || _bu!.isEmpty)) {
      GembaFeedback.showError(context, 'Select a business unit');
      return false;
    }
    return true;
  }

  bool _validateDraftEntry() {
    if (_draftPhoto == null) {
      GembaFeedback.showError(context, 'Add an image for this observation');
      return false;
    }
    if (_draftCategory == null || _draftCategory!.isEmpty) {
      GembaFeedback.showError(context, 'Select a category');
      return false;
    }
    if (_draftEmployeeNumber == null || _draftEmployeeNumber!.isEmpty) {
      GembaFeedback.showError(context, 'Select an assignee');
      return false;
    }
    return true;
  }

  bool get _draftIsEmpty =>
      _draftPhoto == null &&
      (_draftCategory == null || _draftCategory!.isEmpty) &&
      _entryRemarksController.text.trim().isEmpty &&
      (_draftEmployeeNumber == null || _draftEmployeeNumber!.isEmpty);

  bool get _isDraftComplete =>
      _draftPhoto != null &&
      _draftCategory != null &&
      _draftCategory!.isNotEmpty &&
      _draftEmployeeNumber != null &&
      _draftEmployeeNumber!.isNotEmpty;

  _ObservationDraftEntry? _buildDraftEntry() {
    if (!_isDraftComplete) return null;
    return _ObservationDraftEntry(
      photo: _draftPhoto!,
      category: _draftCategory!,
      remarks: _entryRemarksController.text.trim(),
      assignedEmployeeNumber: _draftEmployeeNumber!,
      assignedEmployeeName: _draftEmployeeName,
    );
  }

  List<_ObservationDraftEntry> _entriesToSubmit() {
    final entries = List<_ObservationDraftEntry>.from(_savedEntries);
    final draft = _buildDraftEntry();
    if (draft != null) entries.add(draft);
    return entries;
  }

  int get _pendingSubmitCount => _entriesToSubmit().length;

  String get _submitLabel {
    if (_step == 0) return 'Continue';
    final count = _pendingSubmitCount;
    if (count <= 1) return 'Save observation';
    return 'Save observations ($count)';
  }

  Future<void> _loadEmployees() async {
    if (_employeesLoading) return;

    if (_bu == null || !GembaOrgData.hasEmployeeLookup(_bu)) {
      setState(() {
        _employeesLoading = false;
        _employees = GembaDemoData.withDemoEmployee(const []);
        _employeesError =
            'Employee lookup is not configured for this BU. Demo assignee is available.';
      });
      return;
    }

    setState(() {
      _employeesLoading = true;
      _employeesError = null;
      _employees = GembaDemoData.withDemoEmployee(_employees);
    });
    try {
      final list = await _gembaAuth.listEmployees(bu: _bu!);
      if (!mounted) return;
      setState(() {
        _employees = list;
        _employeesLoading = false;
        _employeesError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _employees = GembaDemoData.withDemoEmployee(const []);
        _employeesLoading = false;
        _employeesError =
            '${e.toString().replaceFirst('Exception: ', '')} Demo assignee is still available.';
      });
    }
  }

  Future<void> _goNext() async {
    if (_step == 0) {
      if (!_validateStep0()) return;
      setState(() => _step = 1);
      _loadEmployees();
      await _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _submitAll();
  }

  Future<void> _goBack() async {
    if (_step <= 0) return;
    setState(() => _step -= 1);
    await _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pickDraftPhoto(ImageSource source) async {
    if (source == ImageSource.camera) {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() => _draftPhoto = file);
      return;
    }
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() => _draftPhoto = files.first);
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDraftPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDraftPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearDraftEntry() {
    _entryRemarksController.clear();
    setState(() {
      _draftPhoto = null;
      _draftCategory = null;
      _draftEmployeeNumber = null;
    });
  }

  void _saveCurrentEntry() {
    if (!_validateDraftEntry()) return;
    setState(() {
      _savedEntries.add(_buildDraftEntry()!);
    });
    _clearDraftEntry();
    GembaFeedback.showSuccess(
      context,
      'Entry saved successfully (${_savedEntries.length} ready to submit)',
    );
  }

  void _removeSavedEntry(int index) {
    setState(() => _savedEntries.removeAt(index));
  }

  Future<void> _submitAll() async {
    if (!_validateStep0()) return;

    if (!_draftIsEmpty && !_isDraftComplete) {
      _validateDraftEntry();
      return;
    }

    final entries = _entriesToSubmit();
    if (entries.isEmpty) {
      _validateDraftEntry();
      return;
    }

    final session = await GembaSessionService.instance.loadSession();
    if (session == null) {
      GembaFeedback.showError(context, 'Sign in again to submit observations');
      return;
    }

    setState(() => _saving = true);
    try {
      var submitted = 0;
      for (final entry in entries) {
        final observationId =
            '${DateTime.now().microsecondsSinceEpoch}_$submitted';
        final photoPaths = await GembaObservationPhotos.persistPhotos(
          observationId: observationId,
          photos: [entry.photo],
        );
        final observation = GembaObservation(
          id: observationId,
          title: _buildTitle(entry.remarks, entry.category),
          location: _buildLocation(),
          category: entry.category,
          status: GembaObservationStatus.inProgress,
          assignedEmployeeNumber: entry.assignedEmployeeNumber,
          assignedEmployeeName: entry.assignedEmployeeName,
          createdByEmployeeNumber: session.user.employeeNumber,
          createdByName: session.user.name,
          remarks: entry.remarks,
          company: _company,
          bu: _bu,
          section: _section,
          machineValue: _machineValue,
          photoPaths: photoPaths,
          createdAt: DateTime.now(),
        );
        await GembaObservationsService.instance.add(observation);
        submitted++;
      }

      if (!mounted) return;
      _resetForm();
      GembaFeedback.showSuccess(
        context,
        submitted == 1
            ? 'Observation saved successfully'
            : '$submitted observations saved successfully',
      );
      widget.onObservationSubmitted?.call();
    } catch (e) {
      if (!mounted) return;
      GembaFeedback.showError(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetForm() {
    _clearDraftEntry();
    _savedEntries.clear();
    _step = 0;
    _pageController.jumpToPage(0);
    setState(() {});
  }

  String _buildTitle(String remarks, String category) {
    if (remarks.isNotEmpty) {
      final line = remarks.split('\n').first.trim();
      if (line.length <= 80) return line;
      return '${line.substring(0, 77)}...';
    }
    return category;
  }

  String _buildLocation() {
    final parts = <String>[];
    if (_section != null && _section!.isNotEmpty) parts.add(_section!);
    if (_bu != null && _bu!.isNotEmpty) parts.add(_bu!);
    parts.add(_company);
    return parts.join(' – ');
  }

  String? get _draftEmployeeName {
    if (_draftEmployeeNumber == null) return null;
    for (final e in _employees) {
      if (e.employeeNumber == _draftEmployeeNumber) {
        final name = e.name?.trim();
        return (name == null || name.isEmpty) ? null : name;
      }
    }
    return null;
  }

  String _employeeLabel(String employeeNumber) {
    for (final e in _employees) {
      if (e.employeeNumber == employeeNumber) return e.label;
    }
    return employeeNumber;
  }

  String get _machineLabel {
    if (_machineValue == null) return '—';
    for (final m in _machines) {
      if (m.value == _machineValue) return m.label;
    }
    return _machineValue!;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: GembaColors.scaffoldGradient,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New observation',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: GembaColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Step ${_step + 1} of 2 · ${_stepMeta[_step].title}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                _StepProgress(current: _step, steps: _stepMeta),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildDetailsStep(),
                _buildObservationsStep(),
              ],
            ),
          ),
          _BottomBar(
            step: _step,
            saving: _saving,
            onBack: _step == 0 ? null : _goBack,
            onPrimary: _goNext,
            primaryLabel: _submitLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PanelHeader(
                icon: Icons.map_outlined,
                title: 'Location',
                subtitle: 'Select company, BU, section — machine is optional',
              ),
              const SizedBox(height: 18),
              GembaSearchablePickerField(
                label: 'Company',
                hint: 'Select company',
                value: _company,
                options: _companyOptions,
                searchHint: 'Search companies…',
                icon: Icons.apartment_rounded,
                onSelected: _onCompanyChanged,
              ),
              if (_isPcl) ...[
                const SizedBox(height: 16),
                GembaSearchablePickerField(
                  label: 'Business Unit',
                  hint: 'Select business unit',
                  value: _bu,
                  options: _pclBuOptions,
                  searchHint: 'Search BU…',
                  icon: Icons.business_rounded,
                  onSelected: _onBuChanged,
                ),
                if (_bu != null) ...[
                  const SizedBox(height: 16),
                  GembaSearchablePickerField(
                    label: 'Section',
                    hint: 'Choose a section',
                    value: _section,
                    options: _sectionOptions,
                    searchHint: 'Search sections…',
                    icon: Icons.grid_view_rounded,
                    onSelected: _onSectionChanged,
                  ),
                ],
                if (_showMachine) ...[
                  const SizedBox(height: 16),
                  GembaSearchablePickerField(
                    label: 'Machine (optional)',
                    hint: 'Select a machine',
                    value: _machineValue,
                    options: _machineOptions,
                    searchHint: 'Search by code or name…',
                    icon: Icons.precision_manufacturing_outlined,
                    onSelected: (v) => setState(() => _machineValue = v),
                  ),
                ],
              ] else if (_isTriPack) ...[
                const SizedBox(height: 16),
                GembaSearchablePickerField(
                  label: 'Business Unit',
                  hint: 'Choose a business unit',
                  value: _bu,
                  options: _tripackBuOptions,
                  searchHint: 'Search business units…',
                  icon: Icons.business_rounded,
                  onSelected: _onBuChanged,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildObservationsStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PanelHeader(
                icon: Icons.add_a_photo_outlined,
                title: 'Add observation entry',
                subtitle:
                    'Image, category, optional remarks & assignee — repeat for multiple findings',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryChip(label: _company),
                  if (_bu != null) _SummaryChip(label: _bu!),
                  if (_section != null) _SummaryChip(label: _section!),
                  if (_machineValue != null)
                    _SummaryChip(label: _machineLabel),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CompactPhotoPicker(
                    photo: _draftPhoto,
                    onTap: _showPhotoSourceSheet,
                    onRemove: _draftPhoto == null
                        ? null
                        : () => setState(() => _draftPhoto = null),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GembaSearchablePickerField(
                      label: 'Category',
                      hint: 'Select category',
                      value: _draftCategory,
                      options: _categoryOptions,
                      searchHint: 'Search categories…',
                      icon: Icons.category_outlined,
                      onSelected: (v) => setState(() => _draftCategory = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _entryRemarksController,
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(fontSize: 15, height: 1.4),
                decoration: InputDecoration(
                  labelText: 'Remarks (optional)',
                  hintText: 'Describe this finding…',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: GembaColors.brandPrimary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 14),
              if (_employeesLoading && _employees.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_employeesError != null) ...[
                Text(
                  _employeesError!,
                  style: const TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (_employees.isNotEmpty)
                GembaSearchablePickerField(
                  label: 'Assign to',
                  hint: 'Select assignee',
                  value: _draftEmployeeNumber,
                  options: _employeeOptions,
                  searchHint: 'Search number or name…',
                  icon: Icons.person_search_rounded,
                  onSelected: (v) => setState(() => _draftEmployeeNumber = v),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _saveCurrentEntry,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save entry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GembaColors.brandPrimary,
                    side: const BorderSide(color: Color(0xFF99F6E4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_savedEntries.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${_savedEntries.length} saved entr${_savedEntries.length == 1 ? 'y' : 'ies'}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: GembaColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _savedEntries.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SavedEntryCard(
                index: i + 1,
                entry: _savedEntries[i],
                assigneeLabel: _employeeLabel(
                  _savedEntries[i].assignedEmployeeNumber,
                ),
                onRemove: () => _removeSavedEntry(i),
              ),
            ),
        ],
      ],
    );
  }
}

class _CompactPhotoPicker extends StatelessWidget {
  const _CompactPhotoPicker({
    required this.photo,
    required this.onTap,
    this.onRemove,
  });

  final XFile? photo;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Image',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          Material(
            color: GembaColors.brandTint,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: photo == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              color: GembaColors.brandPrimary, size: 28),
                          SizedBox(height: 6),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: GembaColors.brandPrimary,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.file(
                              File(photo!.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (onRemove != null)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Material(
                                color: Colors.black54,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: onRemove,
                                  child: const Padding(
                                    padding: EdgeInsets.all(3),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedEntryCard extends StatelessWidget {
  const _SavedEntryCard({
    required this.index,
    required this.entry,
    required this.assigneeLabel,
    required this.onRemove,
  });

  final int index;
  final _ObservationDraftEntry entry;
  final String assigneeLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(entry.photo.path),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$index · ${entry.category}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.remarks.trim().isEmpty
                      ? 'No remarks'
                      : entry.remarks,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    height: 1.3,
                    fontStyle: entry.remarks.trim().isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Assigned: $assigneeLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: GembaColors.brandPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
            color: const Color(0xFF94A3B8),
            tooltip: 'Remove entry',
          ),
        ],
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current, required this.steps});

  final int current;
  final List<({String title, String subtitle, IconData icon})> steps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: i <= current
                        ? GembaColors.brandPrimary
                        : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                    boxShadow: i == current
                        ? [
                            BoxShadow(
                              color: GembaColors.brandPrimary
                                  .withValues(alpha: 0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    i < current ? Icons.check_rounded : steps[i].icon,
                    size: 20,
                    color: i <= current ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  steps[i].title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        i == current ? FontWeight.w800 : FontWeight.w600,
                    color: i <= current
                        ? GembaColors.ink
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 3,
                  decoration: BoxDecoration(
                    color: i < current
                        ? GembaColors.brandPrimary
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: GembaColors.brandTint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: GembaColors.brandPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.saving,
    required this.onPrimary,
    required this.primaryLabel,
    this.onBack,
  });

  final int step;
  final bool saving;
  final Future<void> Function()? onBack;
  final Future<void> Function() onPrimary;
  final String primaryLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (onBack != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : () => onBack?.call(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GembaColors.brandPrimary,
                    side: const BorderSide(color: Color(0xFF99F6E4)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: onBack == null ? 1 : 2,
              child: ElevatedButton(
                onPressed: saving ? null : () => onPrimary(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GembaColors.brandPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        primaryLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
