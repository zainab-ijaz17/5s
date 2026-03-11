import 'package:flutter/material.dart';
import '../../routes.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TakeTestScreen extends StatefulWidget {
  const TakeTestScreen({super.key});

  @override
  State<TakeTestScreen> createState() => _TakeTestScreenState();
}

class _TakeTestScreenState extends State<TakeTestScreen> {
  final Map<String, List<String>> pclBUSections = {
    'BUFC': [
      'Folding & Gluing',
      'Offset Printing',
      'Roto Line',
      'Sorting & Breaking'
    ],
    'BUFP': ['Printing', 'Lamination', 'Extrusion', 'Slitting'],
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
  bool _restoredSelections = false;

  @override
  void initState() {
    super.initState();
    _fetchUserBusinessUnit();
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
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final employeeId = int.parse(currentUser.email!.split('@').first);
        final userDoc = await UserService.getUserByEmployeeId(employeeId);

        if (userDoc != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final buField = userData['business_unit'];

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

    final String? powerUserBUValue =
        (selectedBU != null && pclBUSections.containsKey(selectedBU))
            ? selectedBU
            : (userBusinessUnit != null &&
                    pclBUSections.containsKey(userBusinessUnit))
                ? userBusinessUnit
                : null;

    return Scaffold(
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
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
                    onTap: () async {
                      // Validate selections
                      if (companyChoice == 'Packages Convertors Limited') {
                        String buToUse = selectedBU ?? userBusinessUnit ?? '';
                        if (buToUse.isEmpty || selectedSection == null) return;
                        appState.selectCompany(companyChoice);
                        appState.selectBU(buToUse);
                        appState.selectSection(selectedSection!);

                        // Save user's BU/section selection
                        await _saveUserBusinessUnit(buToUse, selectedSection!);
                      } else if (companyChoice == 'Tri-Pack') {
                        if (selectedBU == null) return;
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

                      Navigator.pushNamed(context, Routes.assessment);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text('Start Assessment',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              )),
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
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get employee ID from email
      final employeeId = int.parse(currentUser.email!.split('@').first);

      // Find user document
      final userDoc = await UserService.getUserByEmployeeId(employeeId);
      if (userDoc != null) {
        await UserService.updateUserBusinessUnit(
          userId: userDoc.id,
          businessUnit: businessUnit,
          section: section,
        );
      }
    } catch (e) {
      print('Error saving user business unit: $e');
    }
  }
}
