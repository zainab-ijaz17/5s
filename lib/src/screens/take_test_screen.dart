import 'package:flutter/material.dart';
import '../../routes.dart';
import '../widgets/role_bottom_nav.dart';
import '../navigation/role_section.dart';
import '../navigation/role_navigation.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/user_service.dart';
import '../services/session_service.dart';
import '../services/assessment_draft_service.dart';
import '../models/assessment_draft.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/assessment_draft_banner.dart';

class TakeTestScreen extends StatefulWidget {
  const TakeTestScreen({super.key});

  @override
  State<TakeTestScreen> createState() => _TakeTestScreenState();
}

class _TakeTestScreenState extends State<TakeTestScreen>
    with WidgetsBindingObserver {
  final Map<String, List<String>> pclBUSections = {
    'BUFC': [
      'Folding & Gluing',
      'Offset Printing',
      'Roto Line',
      'Sorting & Breaking'
    ],
    'BUFP': ['Printing', 'Lamination', 'Extrusion', 'Slitting', 'Mechanical Workshop', 'Electrical Workshop'],
    'BUCP': ['Facial Tissue', 'Non-Tissue', 'Tissue Roll', 'PM-09', 'FemCare'],
  };

  final List<String> tripackBusinessUnits = [
    'PS5',
    'PS7',
    'MOPP',
    'MCPP',
    'CPP Slitters',
    'BOPP SS',
    'Erema',
    'CPP Lines',
    'BOPP Line 4',
    'BOPP Line 5',
    'Power House',
    'Utilities',
    'Store',
    'Waste Yard',
    'Dispatch & FG Hall',
    'Line-3',
    'E&I Workshop',
    'Utilities Workshop',
  ];

  final List<String> companies = const [
    'Packages Convertors Limited',
    'Packages Limited',
    'Bulleh Shah Packaging',
    'Tri-Pack',
    'DIC',
    'OmyaPack',
    'StarchPack',
    'Packages Mall',
  ];

  String companyChoice = 'Packages Convertors Limited';
  String? selectedBU;
  String? selectedSection;
  String? userBusinessUnit; // User's BU from Firestore
  bool isLoadingBU = false;
  bool _isStarting = false;
  bool _restoredSelections = false;
  AssessmentDraft? _draft;
  bool _draftPromptShown = false;

  bool _isTakeTestVisible() {
    final route = ModalRoute.of(context);
    return mounted && (route?.isCurrent ?? false);
  }

  Future<void> _openAssessment({bool resumeDraft = false}) async {
    await Navigator.pushNamed(
      context,
      Routes.assessment,
      arguments: resumeDraft ? const {'resumeDraft': true} : null,
    );
    if (!mounted) return;
    _draftPromptShown = false;
    await _loadDraft();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserBusinessUnit();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDraft());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (AssessmentDraftService.instance.isAssessmentScreenOpen) return;
      if (!_isTakeTestVisible()) return;
      _loadDraft(showPrompt: true);
    }
  }

  Future<void> _loadDraft({bool showPrompt = false}) async {
    if (!mounted) return;
    if (AssessmentDraftService.instance.isAssessmentScreenOpen) return;

    final appState = Provider.of<AppState>(context, listen: false);
    final draft = await AssessmentDraftService.instance.loadDraft(
      userId: appState.currentUser?.id,
      employeeId: appState.currentUser?.employeeId,
    );
    if (!mounted) return;

    setState(() => _draft = draft);

    if (draft != null &&
        showPrompt &&
        !_draftPromptShown &&
        _isTakeTestVisible() &&
        !AssessmentDraftService.instance.isAssessmentScreenOpen) {
      _draftPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_isTakeTestVisible() ||
            AssessmentDraftService.instance.isAssessmentScreenOpen) {
          return;
        }
        _showDraftResumeSheet(draft);
      });
    }
  }

  Future<void> _showDraftResumeSheet(AssessmentDraft draft) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: AssessmentDraftBanner(
          draft: draft,
          onContinue: () {
            Navigator.pop(ctx);
            _continueDraft(draft);
          },
          onDiscard: () {
            Navigator.pop(ctx);
            _discardDraft();
          },
        ),
      ),
    );
  }

  Future<void> _continueDraft(AssessmentDraft draft) async {
    final appState = Provider.of<AppState>(context, listen: false);
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

    setState(() {
      companyChoice = draft.company;
      selectedBU = draft.bu;
      selectedSection = draft.section;
    });

    await SessionService.instance.saveAssessmentContext(
      auditor: draft.auditorName,
      auditee: draft.auditeeName,
      company: draft.company,
      bu: draft.bu,
      section: draft.section,
      lastRoute: Routes.takeTest,
    );

    if (!mounted) return;
    await _openAssessment(resumeDraft: true);
  }

  Future<void> _discardDraft() async {
    await AssessmentDraftService.instance.clearDraft();
    if (!mounted) return;
    setState(() => _draft = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Previous assessment draft discarded.'),
        backgroundColor: Color(0xFF64748B),
      ),
    );
  }

  Future<bool> _handleStartWithDraftCheck() async {
    if (_draft == null) return true;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assessment in progress'),
        content: const Text(
          'You have an unfinished assessment. Would you like to continue it or start a new one?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Start New'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'continue'),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (choice == 'continue') {
      await _continueDraft(_draft!);
      return false;
    }
    if (choice == 'discard') {
      await _discardDraft();
      return true;
    }
    return false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoredSelections) return;

    final appState = Provider.of<AppState>(context);
    if (appState.selectedCompany != null &&
        companies.contains(appState.selectedCompany)) {
      companyChoice = appState.selectedCompany!;

      final restoredBU = appState.selectedBU;
      if (restoredBU != null &&
          restoredBU.isNotEmpty &&
          pclBUSections.containsKey(restoredBU)) {
        selectedBU = restoredBU;
      }

      final restoredSection = appState.selectedSection;
      if (restoredSection != null && restoredSection.isNotEmpty) {
        selectedSection = restoredSection;
      }
    }

    _restoredSelections = true;
  }

  Future<void> _fetchUserBusinessUnit() async {
    setState(() => isLoadingBU = true);
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final employeeId = appState.currentUser?.employeeId;
      if (employeeId != null) {
        final userDoc = await UserService.getUserByEmployeeId(employeeId);

        if (userDoc != null) {
          final userData = Map<String, dynamic>.from(userDoc);
          final buField = userData['businessUnit'] ?? userData['business_unit'];

          String? bu;
          if (buField is Map) {
            final buMap = buField as Map<String, dynamic>;
            // Get the first key from the map (the actual BU code)
            if (buMap.isNotEmpty) {
              bu = buMap.keys.first;
            }
          } else if (buField is String) {
            bu = buField;
          }

          setState(() {
            userBusinessUnit = bu;
            // Auto-select user's BU if it exists in PCL structure
            if (bu != null && bu.isNotEmpty && pclBUSections.containsKey(bu)) {
              selectedBU = bu;
              selectedSection = null; // Reset section when BU changes
            }
          });
        }
      }
    } catch (e) {
      print('Error fetching user business unit: $e');
    } finally {
      setState(() => isLoadingBU = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final showRoleSwitcher = RoleNavigation.showSwitcherFor(appState);

    final String? powerUserBUValue =
        (selectedBU != null && pclBUSections.containsKey(selectedBU))
            ? selectedBU
            : (userBusinessUnit != null &&
                    pclBUSections.containsKey(userBusinessUnit))
                ? userBusinessUnit
                : null;

    return LoadingOverlay(
      isLoading: isLoadingBU || _isStarting,
      message: isLoadingBU ? 'Loading your profile...' : 'Starting assessment...',
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          '5S Assessment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: !showRoleSwitcher,
        leading: showRoleSwitcher
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: 'Login',
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              Routes.login,
              (route) => false,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_draft != null) ...[
                AssessmentDraftBanner(
                  draft: _draft!,
                  onContinue: () => _continueDraft(_draft!),
                  onDiscard: _discardDraft,
                  compact: true,
                ),
                const SizedBox(height: 20),
              ],
              const SizedBox(height: 20),
              // Top Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0891B2),
                      Color(0xFF0EA5E9),
                    ],
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
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.assignment,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '5S Digital Assessment',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Evaluate your workplace organization and efficiency',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Info Card
              Container(
                padding: const EdgeInsets.all(20),
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
                    _buildInfoRow(
                      Icons.quiz,
                      'Questions',
                      '10 Questions',
                      const Color(0xFF0891B2),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.timer,
                      'Duration',
                      '25-30 Minutes',
                      const Color(0xFF0EA5E9),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.category,
                      'Categories',
                      'Sort, Set, Shine, Standardize, Sustain',
                      const Color(0xFF06B6D4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Company/BU/Section Dropdown
              Container(
                width: double.infinity,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Company',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: companyChoice,
                      isExpanded: true,
                      items: companies
                          .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          companyChoice = value;
                          selectedBU = null;
                          selectedSection = null;
                          Provider.of<AppState>(context, listen: false)
                              .selectCompany(value);
                        });
                      },
                    ),
                    if (companyChoice == 'Packages Convertors Limited') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Business Unit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (appState.isPowerUser)
                        DropdownButton<String>(
                          value: powerUserBUValue,
                          hint: const Text('Select business unit'),
                          isExpanded: true,
                          items: pclBUSections.keys
                              .map((bu) =>
                                  DropdownMenuItem(value: bu, child: Text(bu)))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              selectedBU = value;
                              selectedSection =
                                  null; // Reset section when BU changes
                            });
                            Provider.of<AppState>(context, listen: false)
                                .selectBU(value);
                            Provider.of<AppState>(context, listen: false)
                                .selectSection(null);
                          },
                        )
                      else if (userBusinessUnit == null ||
                          userBusinessUnit!.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.business, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Business Unit not assigned',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.business, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  userBusinessUnit!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if ((selectedBU ?? userBusinessUnit) != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Select Section',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButton<String>(
                          value: selectedSection,
                          hint: const Text('Choose a section'),
                          isExpanded: true,
                          items:
                              (pclBUSections[selectedBU ?? userBusinessUnit] ??
                                      [])
                                  .map((s) => DropdownMenuItem(
                                      value: s, child: Text(s)))
                                  .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedSection = value;
                            });
                            Provider.of<AppState>(context, listen: false)
                                .selectSection(value);
                          },
                        ),
                      ],
                    ] else if (companyChoice == 'Tri-Pack') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Select Business Unit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        value: selectedBU,
                        hint: const Text('Choose a business unit'),
                        isExpanded: true,
                        items: tripackBusinessUnits
                            .map((bu) =>
                                DropdownMenuItem(value: bu, child: Text(bu)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedBU = value;
                          });
                          if (value != null) {
                            Provider.of<AppState>(context, listen: false)
                                .selectBU(value);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Start Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF0891B2),
                      Color(0xFF0EA5E9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0891B2).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isStarting
                        ? null
                        : () async {
                      setState(() => _isStarting = true);
                      try {
                      if (!await _handleStartWithDraftCheck()) return;

                      if (!await RoleNavigation.ensureAuditorAuditee(context)) {
                        return;
                      }

                      // Validate selections
                      if (companyChoice == 'Packages Convertors Limited') {
                        String buToUse = selectedBU ?? userBusinessUnit ?? '';
                        if (buToUse.isEmpty || selectedSection == null) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please select business unit and section.',
                                ),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                          }
                          return;
                        }
                        appState.selectCompany(companyChoice);
                        appState.selectBU(buToUse);
                        appState.selectSection(selectedSection!);

                        // Save user's BU/section selection
                        await _saveUserBusinessUnit(buToUse, selectedSection!);
                      } else if (companyChoice == 'Tri-Pack') {
                        if (selectedBU == null) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a business unit.'),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                          }
                          return;
                        }
                        appState.selectCompany(companyChoice);
                        appState.selectBU(selectedBU!);
                        appState.selectSection(null);

                        // Save user's BU selection
                        await _saveUserBusinessUnit(selectedBU!, '');
                      } else {
                        appState.selectCompany(companyChoice);
                        appState.selectBU('');
                        appState.selectSection(null);

                        // Save empty BU for other companies
                        await _saveUserBusinessUnit('', '');
                      }

                      await SessionService.instance.saveAssessmentContext(
                        auditor: appState.auditorName,
                        auditee: appState.auditeeName,
                        company: appState.selectedCompany,
                        bu: appState.selectedBU,
                        section: appState.selectedSection,
                        lastRoute: Routes.takeTest,
                      );

                      await AssessmentDraftService.instance.clearDraft();

                      if (!mounted) return;
                      await _openAssessment();
                      } finally {
                        if (mounted) setState(() => _isStarting = false);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isStarting)
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 24,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _isStarting ? 'Starting...' : 'Start Assessment',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const RoleBottomNav(current: RoleSection.takeTest),
    ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String title, String subtitle, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
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
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveUserBusinessUnit(
      String businessUnit, String section) async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final userId = appState.currentUser?.id;
      if (userId == null || userId.isEmpty) return;

      // Find user document
      await UserService.updateUserBusinessUnit(
        userId: userId,
        businessUnit: businessUnit,
        section: section,
      );
    } catch (e) {
      print('Error saving user business unit: $e');
    }
  }
}
