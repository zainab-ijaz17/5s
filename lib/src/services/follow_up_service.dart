import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/email_service.dart';

class FollowUpService {
  static const Duration _checkInterval = Duration(hours: 1); // Check every hour

  static void startFollowUpScheduler(BuildContext context) {
    // Check for follow-ups immediately and then periodically
    _checkAndSendFollowUps(context);

    // Set up periodic checking (this would typically be done in a background service)
    // For now, we'll check when the app comes to foreground
    WidgetsBinding.instance.addObserver(_LifecycleObserver(context));
  }

  static Future<void> _checkAndSendFollowUps(BuildContext context) async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final emailService = EmailService();

      await appState.sweepFollowUps(emailService);

      print('Follow-up check completed');
    } catch (e) {
      print('Error during follow-up check: $e');
    }
  }

  static Future<void> triggerManualFollowUpCheck(BuildContext context) async {
    await _checkAndSendFollowUps(context);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Follow-up email check completed'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _LifecycleObserver extends WidgetsBindingObserver {
  final BuildContext context;

  _LifecycleObserver(this.context);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check for follow-ups when app comes to foreground
      Future.delayed(const Duration(seconds: 2), () {
        FollowUpService._checkAndSendFollowUps(context);
      });
    }
  }
}
