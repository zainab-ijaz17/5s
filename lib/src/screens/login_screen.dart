import 'package:flutter/material.dart';
import '../../routes.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/session_service.dart';
import '../services/sync_service.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/packages_branded_shell.dart';

const _fiveSPrimary = Color(0xFF0891B2);
const _fiveSPrimaryLight = Color(0xFF0EA5E9);

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  static const Map<String, String> buNames = {
    'BUFC': 'Finished Goods Converters',
    'BUFP': 'Flexible Packaging',
    'BUCP': 'Consumer Products',
  };

  Future<void> _persistSession({
    required app_user.User user,
    String? auditor,
    String? auditee,
    required String lastRoute,
  }) async {
    final token = await ApiService.getAccessToken();
    if (token == null || token.isEmpty) return;
    await SessionService.instance.saveSession(
      user: user,
      accessToken: token,
      auditor: auditor,
      auditee: auditee,
      lastRoute: lastRoute,
    );
  }

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

      final email = "$employeeId@packages.local";

      final authData = await _authService.signIn(email: email, password: password);

      final appState = Provider.of<AppState>(context, listen: false);
      if (await ConnectivityService.instance.isOnline()) {
        SyncService.instance.scheduleSync(appState);
      }

      final data = Map<String, dynamic>.from(authData['user'] ?? {});
      final parsedEmployeeId = data['employeeId'] is int
          ? data['employeeId'] as int
          : int.tryParse(data['employeeId']?.toString() ?? employeeId);
      final resolvedEmail = data['email']?.toString() ?? email;

      final role = (data['role'] as String?) ?? 'normal_user';
      final businessUnit = (data['businessUnit'] as String?) ??
          (data['business_unit'] as String?) ??
          '';
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
          normalizedRole == 'employee' ||
          normalizedRole == 'normal_user' ||
          normalizedRole == 'user' ||
          normalizedRole == 'auditor';

      // ================= POWER USER =================
      if (isPowerUser) {
        final choice = await _showRoleDialog(
          options: ['Take Test', 'BU Dashboard', 'Power Dashboard'],
        );

        if (choice == 'Take Test') {
          final names = await _showAuditorAuditeeDialog();
          if (names != null) {
            final appState = Provider.of<AppState>(context, listen: false);
            final user = app_user.User(
              id: (data['id'] as String?) ?? employeeId,
              name: (data['name'] as String?) ?? '',
              role: role,
              businessUnit: businessUnit,
              employeeId: parsedEmployeeId,
              email: resolvedEmail,
            );
            appState.setLogin(
              user,
              auditor: names['auditor'],
              auditee: names['auditee'],
            );
            await _persistSession(
              user: user,
              auditor: names['auditor'],
              auditee: names['auditee'],
              lastRoute: Routes.takeTest,
            );
            Navigator.pushReplacementNamed(context, Routes.takeTest);
          }
        } else if (choice == 'BU Dashboard') {
          final user = app_user.User(
            id: (data['id'] as String?) ?? employeeId,
            name: (data['name'] as String?) ?? '',
            role: role,
            businessUnit: businessUnit,
            employeeId: parsedEmployeeId,
            email: resolvedEmail,
          );
          appState.setLogin(user);
          await _persistSession(user: user, lastRoute: Routes.buSelection);
          Navigator.pushReplacementNamed(context, Routes.buSelection);
        } else if (choice == 'Power Dashboard') {
          final user = app_user.User(
            id: (data['id'] as String?) ?? employeeId,
            name: (data['name'] as String?) ?? '',
            role: role,
            businessUnit: businessUnit,
            employeeId: parsedEmployeeId,
            email: resolvedEmail,
          );
          appState.setLogin(user);
          await _persistSession(user: user, lastRoute: Routes.powerUser);
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
            final user = app_user.User(
              id: (data['id'] as String?) ?? employeeId,
              name: (data['name'] as String?) ?? '',
              role: role,
              businessUnit: businessUnit,
              employeeId: parsedEmployeeId,
              email: resolvedEmail,
            );
            appState.setLogin(
              user,
              auditor: names['auditor'],
              auditee: names['auditee'],
            );
            await _persistSession(
              user: user,
              auditor: names['auditor'],
              auditee: names['auditee'],
              lastRoute: Routes.takeTest,
            );
            Navigator.pushReplacementNamed(context, Routes.takeTest);
          }
        } else if (choice == 'BU Dashboard') {
          final user = app_user.User(
            id: (data['id'] as String?) ?? employeeId,
            name: (data['name'] as String?) ?? '',
            role: role,
            businessUnit: businessUnit,
            employeeId: parsedEmployeeId,
            email: resolvedEmail,
          );
          appState.setLogin(user);
          await _persistSession(
            user: user,
            lastRoute: Routes.buManagerDashboard,
          );
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
          final user = app_user.User(
            id: (data['id'] as String?) ?? employeeId,
            name: (data['name'] as String?) ?? '',
            role: role,
            businessUnit: businessUnit,
            employeeId: parsedEmployeeId,
            email: resolvedEmail,
          );
          appState.setLogin(
            user,
            auditor: names['auditor'],
            auditee: names['auditee'],
          );
          await _persistSession(
            user: user,
            auditor: names['auditor'],
            auditee: names['auditee'],
            lastRoute: Routes.takeTest,
          );

          Navigator.pushReplacementNamed(context, Routes.takeTest);
        }
      } else {
        final names = await _showAuditorAuditeeDialog();
        if (names == null) {
          setState(() => _isLoading = false);
          return;
        }

        final appState = Provider.of<AppState>(context, listen: false);
        final user = app_user.User(
          id: (data['id'] as String?) ?? employeeId,
          name: (data['name'] as String?) ?? '',
          role: role,
          businessUnit: businessUnit,
          employeeId: parsedEmployeeId,
          email: resolvedEmail,
        );
        appState.setLogin(
          user,
          auditor: names['auditor'],
          auditee: names['auditee'],
        );
        await _persistSession(
          user: user,
          auditor: names['auditor'],
          auditee: names['auditee'],
          lastRoute: Routes.takeTest,
        );
        Navigator.pushReplacementNamed(context, Routes.takeTest);
      }
    } catch (e) {
      _showError(_friendlyLoginError(e));
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

  String _friendlyLoginError(Object e) {
    final raw = e.toString();
    if (raw.contains('CERTIFICATE_VERIFY_FAILED') ||
        raw.contains('HandshakeException')) {
      return 'Secure connection failed. Check date/time, turn off VPN, and try again.';
    }
    if (raw.contains('connection abort') ||
        raw.contains('Connection reset') ||
        raw.contains('SocketException') ||
        raw.contains('failed host lookup') ||
        raw.contains('Network is unreachable')) {
      return 'Network connection was interrupted. Try again on stable Wi‑Fi or mobile data, disable VPN, and ensure the phone is not in power-saving mode.';
    }
    return raw;
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
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Signing in...',
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F7FA),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        Routes.appChooser,
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: _fiveSPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const _FiveSHeaderCard(),
                const SizedBox(height: 28),
                _FiveSLoginCard(
                  employeeIdController: _employeeIdController,
                  passwordController: _passwordController,
                  obscurePassword: _obscurePassword,
                  isLoading: _isLoading,
                  onTogglePassword: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                  onLogin: _handleLogin,
                ),
              ],
            ),
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

class _FiveSHeaderCard extends StatelessWidget {
  const _FiveSHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _fiveSPrimary.withOpacity(0.1),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_fiveSPrimary, _fiveSPrimaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _fiveSPrimary.withOpacity(0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.assessment_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '5S Digital Assessment',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Workplace organization & efficiency',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FiveSLoginCard extends StatelessWidget {
  const _FiveSLoginCard({
    required this.employeeIdController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onLogin,
  });

  final TextEditingController employeeIdController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return PackagesAuthCard(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
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
          const SizedBox(height: 8),
          const Text(
            'Use your employee ID and password to continue.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: employeeIdController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Employee ID',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onLogin(),
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onLogin,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: _fiveSPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Sign in',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
