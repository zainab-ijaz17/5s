import 'package:flutter/material.dart';

import 'api_service.dart';

/// Triggers server-side follow-up email sweep (replaces device SMTP).
class FollowUpService {
  static Future<Map<String, dynamic>> sweepFromServer() async {
    final token = await ApiService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Sign in again to run follow-up emails');
    }

    final response = await ApiService.post(
      '/assessments/follow-ups/sweep',
      const {},
      accessToken: token,
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return const {};
  }

  static Future<void> triggerManualFollowUpCheck(BuildContext context) async {
    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Running follow-up email sweep on server...'),
          backgroundColor: Color(0xFF0891B2),
          duration: Duration(seconds: 2),
        ),
      );

      final result = await sweepFromServer();
      if (!context.mounted) return;

      final processed = result['processed'];
      final sent = result['sent'];
      final errors = result['errors'];
      final errorCount = errors is List ? errors.length : 0;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Follow-up sweep complete: ${sent ?? 0} sent'
            '${processed != null ? ' of $processed due' : ''}'
            '${errorCount > 0 ? ' ($errorCount failed)' : ''}.',
          ),
          backgroundColor:
              errorCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
          duration: Duration(seconds: errorCount > 0 ? 6 : 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
