import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../routes.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/user.dart' as app_user;

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();

  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;

  static const Map<String, String> buNames = {
    'BUFC': 'Finished Goods Converters',
    'BUFP': 'Flexible Packaging',
    'BUCP': 'Consumer Products',
  };

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    try {
      final employeeId = _employeeIdController.text.trim();
      final password = _passwordController.text.trim();

      if (employeeId.isEmpty || password.isEmpty) {
        _showError("Employee ID and password are required");
        setState(() => _isLoading = false);
        return;
      }

      if (!RegExp(r'^\d+$').hasMatch(employeeId)) {
        _showError("Enter a valid numeric Employee ID");
        setState(() => _isLoading = false);
        return;
      }

      // Append company domain
      final email = "$employeeId@packages.local";

      // Sign in with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Query Firestore by employee ID in new structure
      final query = await _firestore
          .collection('company')
          .doc('main')
          .collection('users')
          .where('employeeId', isEqualTo: int.parse(employeeId))
          .limit(1)
          .get();

      Map<String, dynamic> data;

      if (query.docs.isEmpty) {
        // Create user document if it doesn't exist
        await _firestore
            .collection('company')
            .doc('main')
            .collection('users')
            .add({
          'email': email,
          'employeeId': int.parse(employeeId),
          'name': '',
          'role': 'normal_user',
          'business_unit': '',
          'created_at': FieldValue.serverTimestamp(),
          'last_login': FieldValue.serverTimestamp(),
          'assessments': [],
        });

        data = {
          'role': 'normal_user',
          'business_unit': '',
          'name': '',
        };
      } else {
        data = query.docs.first.data();
        // Update last login
        await _firestore
            .collection('company')
            .doc('main')
            .collection('users')
            .doc(query.docs.first.id)
            .update({
          'last_login': FieldValue.serverTimestamp(),
        });
      }

      final role = (data['role'] as String?) ?? 'normal_user';
      String businessUnit;
      if (data['business_unit'] is Map) {
        final buMap = data['business_unit'] as Map<String, dynamic>;
        businessUnit = buMap.keys
            .firstWhere((key) => buMap[key] != null, orElse: () => '');
      } else {
        businessUnit = (data['business_unit'] as String?) ?? '';
      }
      // Debug: Print user role and business unit
      print('DEBUG: User role = "$role"');
      print('DEBUG: Business unit = "$businessUnit"');
      print('DEBUG: Role lowercase = "${role.toLowerCase()}"');

      // Handle role variations for backward compatibility
      final normalizedRole = role.toLowerCase();
      final isPowerUser =
          normalizedRole == 'poweruser' || normalizedRole == 'power_user';
      final isBUManager = normalizedRole == 'bumanager' ||
          normalizedRole == 'bu_manager' ||
          normalizedRole == 'manager';
      final isEmployee =
          normalizedRole == 'employee' || normalizedRole == 'normal_user';

      // ================= POWER USER =================
      if (isPowerUser) {
        final choice = await _showRoleDialog(
          options: ['Take Test', 'BU Dashboard', 'Power Dashboard'],
        );

        if (choice == 'Take Test') {
          final names = await _showAuditorAuditeeDialog();
          if (names != null) {
            final appState = Provider.of<AppState>(context, listen: false);
            appState.setLogin(
              app_user.User(
                id: query.docs.first.id, // Use Firestore document ID
                name: (data['name'] as String?) ?? '',
                role: role,
                businessUnit: businessUnit,
              ),
              auditor: names['auditor'],
              auditee: names['auditee'],
            );
            Navigator.pushReplacementNamed(context, Routes.takeTest);
          }
        } else if (choice == 'BU Dashboard') {
          Navigator.pushReplacementNamed(context, Routes.buSelection);
        } else if (choice == 'Power Dashboard') {
          Navigator.pushReplacementNamed(context, Routes.powerUser);
        }

        setState(() => _isLoading = false);
        return;
      }

      // ================= BU MANAGER =================
      if (isBUManager) {
        final choice = await _showRoleDialog(
          options: ['Take Test', 'BU Dashboard'],
        );

        if (choice == 'Take Test') {
          final names = await _showAuditorAuditeeDialog();
          if (names != null) {
            final appState = Provider.of<AppState>(context, listen: false);
            appState.setLogin(
              app_user.User(
                id: query.docs.first.id, // Use Firestore document ID
                name: (data['name'] as String?) ?? '',
                role: role,
                businessUnit: businessUnit,
              ),
              auditor: names['auditor'],
              auditee: names['auditee'],
            );
            Navigator.pushReplacementNamed(context, Routes.takeTest);
          }
        } else if (choice == 'BU Dashboard') {
          Navigator.pushReplacementNamed(
            context,
            Routes.buManagerDashboard,
            arguments: <String, String>{
              'buCode': businessUnit,
              'buName': buNames[businessUnit] ?? '',
            },
          );
        }

        setState(() => _isLoading = false);
        return;
      }

      // ================= DEFAULT EMPLOYEE =================
      if (isEmployee) {
        final names = await _showAuditorAuditeeDialog();
        if (names != null) {
          // Save names to app state for later use
          final appState = Provider.of<AppState>(context, listen: false);
          appState.setLogin(
            app_user.User(
              id: query.docs.first.id, // Use Firestore document ID
              name: (data['name'] as String?) ?? '',
              role: role,
              businessUnit: businessUnit,
            ),
            auditor: names['auditor'],
            auditee: names['auditee'],
          );

          Navigator.pushReplacementNamed(context, Routes.takeTest);
        }
      } else {
        Navigator.pushReplacementNamed(context, Routes.takeTest);
      }
    } on auth.FirebaseAuthException catch (e) {
      _showError(e.message ?? "Login failed");
    } catch (e) {
      _showError(e.toString());
    }

    setState(() => _isLoading = false);
  }

  Future<String?> _showRoleDialog({required List<String> options}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Choose Destination"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map(
                (option) => TextButton(
                  onPressed: () => Navigator.pop(ctx, option),
                  child: Text(option),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 60),

            // ===== HEADER CARD =====
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0891B2).withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0891B2), Color(0xFF0EA5E9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0891B2).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.assessment_outlined,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '5S Digital Assessment',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Workplace Organization & Efficiency',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ===== LOGIN CARD =====
            Container(
              padding: const EdgeInsets.all(24),
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
                  Text(
                    'Sign In',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // ===== ORIGINAL INPUTS (UNCHANGED) =====
                  TextField(
                    controller: _employeeIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Employee ID",
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ===== ORIGINAL LOGIN BUTTON (UNCHANGED) =====
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: const Color(0xFF0891B2),
                            ),
                            child: const Text("Login"),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Future<Map<String, String>?> _showAuditorAuditeeDialog() async {
    final auditorController = TextEditingController();
    final auditeeController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Enter Assessment Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: auditorController,
              decoration: const InputDecoration(
                labelText: "Auditor Name",
                hintText: "Enter auditor's name",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: auditeeController,
              decoration: const InputDecoration(
                labelText: "Auditee Name",
                hintText: "Enter auditee's name",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final auditor = auditorController.text.trim();
              final auditee = auditeeController.text.trim();

              if (auditor.isNotEmpty && auditee.isNotEmpty) {
                Navigator.pop(ctx, {
                  'auditor': auditor,
                  'auditee': auditee,
                });
              }
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }
}
