import 'dart:io';
import 'lib/src/services/email_service.dart';

void main() async {
  print('Testing email service with updated credentials...');

  // Test the email connection
  final result = await EmailService.testEmailConnection();

  if (result) {
    print('✅ Email service is working!');
  } else {
    print('❌ Email service failed');
  }

  // Show email log
  print('\nEmail log:');
  final log = EmailService.getEmailLog();
  for (final entry in log) {
    print('- ${entry['timestamp']}: ${entry['type']} - ${entry['status']}');
  }

  exit(0);
}
