// lib/src/services/email_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../models/submitted_assessment.dart';
import '../util/assessment_recipients.dart';

// Helper function to get filename from path
String _getFileName(String filePath) {
  // Handle both Windows and Unix paths
  final normalizedPath = filePath.replaceAll('\\', '/');
  final parts = normalizedPath.split('/');
  return parts.isNotEmpty ? parts.last : filePath;
}

// Email providers
enum EmailProvider {
  mailgun,
  sendGrid,
  gmail,
  localSMTP,
}

class EmailService {
  // Email Configuration
  static bool _simulationMode = false; // Disabled - sending actual emails
  static EmailProvider _provider = EmailProvider.localSMTP;

  // Mailgun Configuration (recommended - works well with Laravel)
  static const String _mailgunApiKey =
      'YOUR_MAILGUN_API_KEY'; // REPLACE WITH YOUR ACTUAL API KEY
  static const String _mailgunDomain =
      'sandbox123.mailgun.org'; // REPLACE WITH YOUR DOMAIN
  static const String _mailgunRegion = 'us'; // REPLACE 'us' or 'eu'

  // SendGrid Configuration (alternative)
  static const String _sendGridApiKey = 'YOUR_SENDGRID_API_KEY';
  static const String _fromEmail = 'systems.services@packages.com.pk';
  static const String _fromName = '5S';

  // Local SMTP Configuration (matching Laravel exactly)
  static const String _smtpHost = 'welcome1.packages.com.pk';
  static const int _smtpPort = 587;
  static const String _smtpUser = 'systems.services@packages.com.pk';
  static const String _smtpPass = r'\jR|;52##';

  // Mail Relay Server Configuration
  static const String _mailRelayUrl = 'http://localhost:3000';
  static const String _mailRelayApiKey =
      'YOUR_MAIL_RELAY_API_KEY'; // Set in .env

  // Local email log storage
  static final List<Map<String, dynamic>> _emailLog = [];

  // Get email log for debugging
  static List<Map<String, dynamic>> getEmailLog() => List.from(_emailLog);

  // Clear email log
  static void clearEmailLog() => _emailLog.clear();

  // Set email provider
  static void setEmailProvider(EmailProvider provider) => _provider = provider;

  // Enable/disable simulation mode
  static void setSimulationMode(bool enabled) => _simulationMode = false;

  // Export email log for manual sending
  static String exportEmailLog() {
    if (_emailLog.isEmpty) {
      return 'No emails logged yet.';
    }

    String export = '5S ASSESSMENT EMAIL LOG\n';
    export += '=' * 50 + '\n\n';

    for (var log in _emailLog) {
      export += 'Timestamp: ${log['timestamp']}\n';
      export += 'Type: ${log['type']}\n';
      export += 'From: ${log['from']}\n';
      export += 'To: ${(log['to'] as List).join(', ')}\n';
      export += 'Subject: ${log['subject']}\n';
      export += 'Status: ${log['status']}\n';
      if (log['simulation'] == true) {
        export += 'Note: Email was logged but not sent (simulation mode)\n';
      }
      if (log['assessment_id'] != null) {
        export += 'Assessment ID: ${log['assessment_id']}\n';
      }
      if (log['score'] != null) {
        export += 'Score: ${log['score']}%\n';
      }
      export += '-' * 50 + '\n\n';
    }

    return export;
  }

  // Get pending emails that need manual sending
  static List<Map<String, dynamic>> getPendingEmails() {
    return _emailLog.where((log) => log['simulation'] == true).toList();
  }

  // Test email function for debugging
  static Future<bool> testEmailConnection() async {
    try {
      print('=== TESTING EMAIL CONNECTION ===');
      print('Using provider: $_provider');

      if (_simulationMode) {
        print('SIMULATION MODE: Email test bypassed');
        _logEmail('test_email', ['zainab.ijaz@packages.com.pk'],
            'Test Email - 5S System Connection Test', true);
        print('SUCCESS: Test email logged in simulation mode!');
        return true;
      }

      final testEmail = {
        'subject': 'Test Email - 5S System Connection Test',
        'html':
            '<h1>Test Email</h1><p>This is a test email to verify email service connection.</p>',
        'text':
            'Test Email\n\nThis is a test email to verify email service connection.',
      };

      bool success = await _sendEmail(['zainab.ijaz@packages.com.pk'],
          testEmail['subject']!, testEmail['html']!, testEmail['text']!);

      if (success) {
        print('SUCCESS: Test email sent!');
        return true;
      } else {
        print('ERROR: Test email failed');
        return false;
      }
    } catch (e, stackTrace) {
      print('=== TEST EMAIL ERROR ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Stack trace: $stackTrace');
      print('========================');
      return false;
    }
  }

  // Generate detailed HTML email with all assessment data
  static String _generateAssessmentEmailHtml(SubmittedAssessment sa) {
    final buffer = StringBuffer();

    buffer.write('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body {
      font-family: Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 800px;
      margin: 0 auto;
      padding: 20px;
    }
    .header {
      background-color: #0891B2;
      color: white;
      padding: 20px;
      border-radius: 5px;
      margin-bottom: 20px;
    }
    .info-section {
      background-color: #f5f5f5;
      padding: 15px;
      border-radius: 5px;
      margin-bottom: 20px;
    }
    .info-row {
      margin: 8px 0;
    }
    .info-label {
      font-weight: bold;
      display: inline-block;
      width: 150px;
    }
    .score-badge {
      display: inline-block;
      padding: 5px 15px;
      border-radius: 20px;
      font-weight: bold;
      color: white;
      margin-left: 10px;
    }
    .score-high {
      background-color: #10B981;
    }
    .score-low {
      background-color: #EF4444;
    }
    .question-item {
      border: 1px solid #ddd;
      border-radius: 5px;
      padding: 15px;
      margin-bottom: 15px;
      background-color: #fff;
    }
    .question-item.flagged {
      border-left: 4px solid #EF4444;
      background-color: #FEF2F2;
    }
    .question-number {
      font-weight: bold;
      color: #0891B2;
      margin-bottom: 8px;
    }
    .question-text {
      font-size: 14px;
      margin-bottom: 10px;
    }
    .answer {
      margin: 8px 0;
      padding: 8px;
      background-color: #f9f9f9;
      border-radius: 3px;
    }
    .answer-label {
      font-weight: bold;
      color: #666;
    }
    .answer-value {
      color: #0891B2;
      font-weight: bold;
    }
    .remarks {
      margin-top: 10px;
      padding: 10px;
      background-color: #F0F9FF;
      border-left: 3px solid #0891B2;
      font-style: italic;
    }
    .image-attachment {
      margin-top: 10px;
      padding: 10px;
      background-color: #F0F9FF;
      border-left: 3px solid #0891B2;
    }
    .no-remarks {
      color: #999;
      font-style: italic;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>5S Digital Assessment - Completed</h1>
  </div>
  
  <div class="info-section">
    <h2>Assessment Details</h2>
    <div class="info-row">
      <span class="info-label">Company:</span>
      <span>${_escapeHtml(sa.company)}</span>
    </div>
    <div class="info-row">
      <span class="info-label">Business Unit:</span>
      <span>${_escapeHtml(sa.bu ?? 'N/A')}</span>
    </div>
    <div class="info-row">
      <span class="info-label">Section:</span>
      <span>${_escapeHtml(sa.section ?? 'N/A')}</span>
    </div>
    <div class="info-row">
      <span class="info-label">Auditor:</span>
      <span>${_escapeHtml(sa.auditorName)}</span>
    </div>
    <div class="info-row">
      <span class="info-label">Auditee:</span>
      <span>${_escapeHtml(sa.auditeeName)}</span>
    </div>
    <div class="info-row">
      <span class="info-label">Date:</span>
      <span>${_formatDate(sa.date)}</span>
    </div>
    <div class="info-row">
      <span class="info-label">Score:</span>
      <span>${sa.score}%
      <span class="score-badge ${sa.score >= 90 ? 'score-high' : 'score-low'}">
        ${sa.score >= 90 ? 'PASSED' : 'FLAGGED'}
      </span>
      </span>
    </div>
  </div>
  
  <h2>Assessment Questions & Answers</h2>
''');

    // Add each question and answer
    for (int i = 0; i < sa.items.length; i++) {
      final item = sa.items[i];
      final question = item['question'] as String? ?? '';
      final answer = item['answer'] as String? ?? 'N/A';
      final remarks = item['remarks'] as String? ?? '';
      final imagePath = item['imagePath'] as String?;
      final imagePathsRaw = item['imagePaths'];
      final imageUrlsRaw = item['imageUrls'];
      final imagePaths = imagePathsRaw is List
          ? imagePathsRaw
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];
      final imageUrls = imageUrlsRaw is List
          ? imageUrlsRaw
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];
      final isFlagged = item['isFlagged'] as bool? ?? false;

      buffer.write('''
  <div class="question-item ${isFlagged ? 'flagged' : ''}">
    <div class="question-number">Question ${i + 1}</div>
    <div class="question-text">${_escapeHtml(question)}</div>
    <div class="answer">
      <span class="answer-label">Answer: </span>
      <span class="answer-value">${_escapeHtml(answer)}</span>
    </div>
''');

      if (remarks.isNotEmpty) {
        buffer.write('''
    <div class="remarks">
      <strong>Remarks:</strong> ${_escapeHtml(remarks)}
    </div>
''');
      } else {
        buffer.write('''
    <div class="remarks no-remarks">No remarks provided</div>
''');
      }

      final attachmentNames = <String>[];
      if (imagePath != null && imagePath.isNotEmpty) {
        attachmentNames.add(_getFileName(imagePath));
      }
      for (final p in imagePaths) {
        attachmentNames.add(_getFileName(p));
      }

      if (attachmentNames.isNotEmpty || imageUrls.isNotEmpty) {
        buffer.write('''
    <div class="image-attachment">
      <strong>Images:</strong>
      <div>
''');
        if (attachmentNames.isNotEmpty) {
          buffer.write(
              '<div>Attached: ${attachmentNames.map(_escapeHtml).join(', ')}</div>');
        }
        if (imageUrls.isNotEmpty) {
          buffer.write('<div>Links:</div><ul>');
          for (final url in imageUrls) {
            buffer.write(
                '<li><a href="${_escapeHtml(url)}">${_escapeHtml(url)}</a></li>');
          }
          buffer.write('</ul>');
        }
        buffer.write('''
      </div>
    </div>
''');
      }

      buffer.write('  </div>\n');
    }

    buffer.write('''
  <div style="margin-top: 30px; padding: 15px; background-color: #f5f5f5; border-radius: 5px; text-align: center; color: #666; font-size: 12px;">
    This is an automated email from the 5S Digital Assessment System.
  </div>
</body>
</html>
''');

    return buffer.toString();
  }

  // Generate plain text version of assessment email
  static String _generateAssessmentEmailText(SubmittedAssessment sa) {
    final buffer = StringBuffer();

    buffer.writeln('5S Digital Assessment - Completed');
    buffer.writeln('=' * 50);
    buffer.writeln();
    buffer.writeln('Assessment Details:');
    buffer.writeln('  Company: ${sa.company}');
    buffer.writeln('  Business Unit: ${sa.bu ?? 'N/A'}');
    buffer.writeln('  Section: ${sa.section ?? 'N/A'}');
    buffer.writeln('  Auditor: ${sa.auditorName}');
    buffer.writeln('  Auditee: ${sa.auditeeName}');
    buffer.writeln('  Date: ${_formatDate(sa.date)}');
    buffer.writeln(
        '  Score: ${sa.score}% ${sa.score >= 90 ? '(PASSED)' : '(FLAGGED)'}');
    buffer.writeln();
    buffer.writeln('Assessment Questions & Answers:');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (int i = 0; i < sa.items.length; i++) {
      final item = sa.items[i];
      final question = item['question'] as String? ?? '';
      final answer = item['answer'] as String? ?? 'N/A';
      final remarks = item['remarks'] as String? ?? '';
      final imagePath = item['imagePath'] as String?;
      final imagePathsRaw = item['imagePaths'];
      final imageUrlsRaw = item['imageUrls'];
      final imagePaths = imagePathsRaw is List
          ? imagePathsRaw
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];
      final imageUrls = imageUrlsRaw is List
          ? imageUrlsRaw
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];
      final isFlagged = item['isFlagged'] as bool? ?? false;

      buffer.writeln('Question ${i + 1}${isFlagged ? ' [FLAGGED]' : ''}');
      buffer.writeln(question);
      buffer.writeln('Answer: $answer');
      if (remarks.isNotEmpty) {
        buffer.writeln('Remarks: $remarks');
      }
      final attachmentNames = <String>[];
      if (imagePath != null && imagePath.isNotEmpty) {
        attachmentNames.add(_getFileName(imagePath));
      }
      for (final p in imagePaths) {
        attachmentNames.add(_getFileName(p));
      }

      if (attachmentNames.isNotEmpty) {
        buffer.writeln('Images attached: ${attachmentNames.join(', ')}');
      }
      if (imageUrls.isNotEmpty) {
        for (final url in imageUrls) {
          buffer.writeln('Image link: $url');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  // Helper to escape HTML
  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  // Helper to format date
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Send assessment email
  static Future<bool> sendAssessmentEmail(SubmittedAssessment sa) async {
    try {
      print('=== SENDING ASSESSMENT EMAIL ===');
      print('Assessment details: ${sa.company} - ${sa.bu} - ${sa.section}');

      // Get recipients based on BU and Section
      var recipients = List<String>.from(
          AssessmentRecipients.getRecipients(sa.bu, sa.section));
      print('Initial recipients from AssessmentRecipients: $recipients');

      // If no specific section recipients, get all for BU
      if (recipients.isEmpty) {
        recipients = List<String>.from(
            AssessmentRecipients.getAllRecipientsForBU(sa.bu));
        print('BU-wide recipients: $recipients');
      }

      // Add Zainab Ijaz to all assessment emails
     

      // Add required recipients for Packages Convertors Limited
      if (sa.company == 'Packages Convertors Limited') {
        const List<String> packagesConvertorsRecipients = [
          'usman.muhammad@packages.com.pk',
          'muhammad.ammad@packages.com.pk',
        ];
        for (final email in packagesConvertorsRecipients) {
          if (!recipients.contains(email)) {
            recipients.add(email);
          }
        }
        print('Added Packages Convertors Limited recipients');
      }

      print('Final recipients: $recipients');

      if (recipients.isEmpty) {
        print(
            'ERROR: No email recipients found for BU: ${sa.bu}, Section: ${sa.section}');
        return false;
      }

      final subject =
          '5S Assessment - ${sa.company} - ${sa.bu ?? 'N/A'} - ${sa.section ?? 'N/A'}';
      final html = _generateAssessmentEmailHtml(sa);
      final text = _generateAssessmentEmailText(sa);

      // Collect image files for attachments (supports legacy imagePath and new imagePaths)
      final List<File> imageFiles = [];
      for (final item in sa.items) {
        final single = item['imagePath'] as String?;
        final imagePathsRaw = item['imagePaths'];
        final paths = <String>[];
        if (single != null && single.isNotEmpty) paths.add(single);
        if (imagePathsRaw is List) {
          paths.addAll(imagePathsRaw
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty));
        }

        for (final p in paths) {
          try {
            final file = File(p);
            if (await file.exists()) {
              imageFiles.add(file);
            }
          } catch (e) {
            print('Warning: Could not access image file: $p - $e');
          }
        }
      }

      print('Found ${imageFiles.length} image(s) to attach');

      bool success = await _sendEmailWithAttachments(
          recipients, subject, html, text, imageFiles);

      _logEmail('assessment_email', recipients, subject, success,
          assessmentId: sa.id, score: sa.score);

      if (success) {
        print('SUCCESS: Assessment email sent!');
        return true;
      } else {
        print('ERROR: Assessment email failed');
        return false;
      }
    } catch (e, stackTrace) {
      print('=== ASSESSMENT EMAIL ERROR ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Stack trace: $stackTrace');
      print('========================');
      return false;
    }
  }

  // Send follow-up email
  static Future<bool> sendFollowUpEmail(SubmittedAssessment sa) async {
    try {
      print('=== SENDING FOLLOW-UP EMAIL ===');

      // Get recipients for follow-up (same as assessment for now)
      var recipients = List<String>.from(
          AssessmentRecipients.getRecipients(sa.bu, sa.section));
      if (recipients.isEmpty) {
        recipients = List<String>.from(
            AssessmentRecipients.getAllRecipientsForBU(sa.bu));
      }

      // Add Zainab Ijaz to all follow-up emails
     

      // Add required recipients for Packages Convertors Limited
      if (sa.company == 'Packages Convertors Limited') {
        const List<String> packagesConvertorsRecipients = [
          'usman.muhammad@packages.com.pk',
          'muhammad.ammad@packages.com.pk',
        ];
        for (final email in packagesConvertorsRecipients) {
          if (!recipients.contains(email)) {
            recipients.add(email);
          }
        }
      }

      if (recipients.isEmpty) {
        print('ERROR: No email recipients found for follow-up');
        return false;
      }

      final subject =
          'Follow-up: 5S Assessment - ${sa.company} - ${sa.bu} - ${sa.section}';
      final html =
          '<h2>Follow-up: 5S Assessment</h2><p>Follow-up required for assessment: ${sa.company} - ${sa.bu} - ${sa.section}</p>';
      final text =
          'Follow-up: 5S Assessment\n\nFollow-up required for assessment: ${sa.company} - ${sa.bu} - ${sa.section}';

      bool success = await _sendEmail(recipients, subject, html, text);

      _logEmail('follow_up_email', recipients, subject, success,
          assessmentId: sa.id, score: sa.score);

      if (success) {
        print('SUCCESS: Follow-up email sent!');
        return true;
      } else {
        print('ERROR: Follow-up email failed');
        return false;
      }
    } catch (e, stackTrace) {
      print('=== FOLLOW-UP EMAIL ERROR ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Stack trace: $stackTrace');
      print('========================');
      return false;
    }
  }

  // Send email using selected provider
  static Future<bool> _sendEmail(
      List<String> recipients, String subject, String html, String text) async {
    return await _sendEmailWithAttachments(recipients, subject, html, text, []);
  }

  // Send email with attachments
  static Future<bool> _sendEmailWithAttachments(List<String> recipients,
      String subject, String html, String text, List<File> attachments) async {
    if (_simulationMode) {
      print('SIMULATION MODE: Email logged but not sent');
      if (attachments.isNotEmpty) {
        print('  Attachments: ${attachments.length} file(s)');
      }
      return true;
    }

    switch (_provider) {
      case EmailProvider.mailgun:
        return _sendViaMailgun(recipients, subject, html, text, attachments);
      case EmailProvider.sendGrid:
        return _sendViaSendGrid(recipients, subject, html, text, attachments);
      case EmailProvider.gmail:
        return _sendViaGmailSMTP(recipients, subject, html, text, attachments);
      case EmailProvider.localSMTP:
        return _sendViaLocalSMTP(recipients, subject, html, text, attachments);
    }
  }

  // Send email via Mailgun API
  static Future<bool> _sendViaMailgun(List<String> recipients, String subject,
      String html, String text, List<File> attachments) async {
    try {
      // Use region-specific URL for Mailgun
      const mailgunUrl = _mailgunRegion == 'eu'
          ? 'https://api.eu.mailgun.net/v3/$_mailgunDomain/messages'
          : 'https://api.mailgun.net/v3/$_mailgunDomain/messages';

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(mailgunUrl),
      );

      request.headers['Authorization'] =
          'Basic ${base64.encode(utf8.encode('api:$_mailgunApiKey'))}';

      request.fields['from'] = '$_fromName <$_fromEmail>';
      request.fields['to'] = recipients.join(',');
      request.fields['subject'] = subject;
      request.fields['html'] = html;
      request.fields['text'] = text;

      // Add attachments
      for (final file in attachments) {
        try {
          final bytes = await file.readAsBytes();
          final fileName = _getFileName(file.path);
          request.files.add(http.MultipartFile.fromBytes(
            'attachment',
            bytes,
            filename: fileName,
          ));
        } catch (e) {
          print('Warning: Could not attach file ${file.path}: $e');
        }
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('Mailgun response: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('Mailgun error response: $responseBody');
      }
      return response.statusCode == 200;
    } catch (e) {
      print('Mailgun error: $e');
      return false;
    }
  }

  // Send email via SendGrid API
  static Future<bool> _sendViaSendGrid(List<String> recipients, String subject,
      String html, String text, List<File> attachments) async {
    try {
      final attachmentsList = <Map<String, dynamic>>[];

      // Process attachments
      for (final file in attachments) {
        try {
          final bytes = await file.readAsBytes();
          final base64Content = base64.encode(bytes);
          final fileName = _getFileName(file.path);
          attachmentsList.add({
            'content': base64Content,
            'filename': fileName,
            'type':
                'image/jpeg', // Default, could be improved with MIME detection
            'disposition': 'attachment',
          });
        } catch (e) {
          print('Warning: Could not attach file ${file.path}: $e');
        }
      }

      final body = {
        'personalizations': [
          {
            'to': recipients.map((email) => {'email': email}).toList(),
            'subject': subject,
          }
        ],
        'from': {'email': _fromEmail, 'name': _fromName},
        'content': [
          {'type': 'text/html', 'value': html},
          {'type': 'text/plain', 'value': text},
        ],
        if (attachmentsList.isNotEmpty) 'attachments': attachmentsList,
      };

      final response = await http.post(
        Uri.parse('https://api.sendgrid.com/v3/mail/send'),
        headers: {
          'Authorization': 'Bearer $_sendGridApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('SendGrid response: ${response.statusCode}');
      if (response.statusCode != 202) {
        print('SendGrid error response: ${response.body}');
      }
      return response.statusCode == 202;
    } catch (e) {
      print('SendGrid error: $e');
      return false;
    }
  }

  // Send email via Gmail SMTP (using Mailgun or similar service)
  static Future<bool> _sendViaGmailSMTP(List<String> recipients, String subject,
      String html, String text, List<File> attachments) async {
    // For Gmail, we recommend using a service like Mailgun or SendGrid
    // This is a placeholder for Gmail SMTP implementation
    print('Gmail SMTP not implemented - please use SendGrid or local SMTP');
    return false;
  }

  // Send email via local SMTP (direct SMTP connection)
  static Future<bool> _sendViaLocalSMTP(List<String> recipients, String subject,
      String html, String text, List<File> attachments) async {
    // SMTP doesn't work on web - use HTTP mail relay instead
    if (kIsWeb) {
      print('⚠️ SMTP not supported on web platform. Using HTTP mail relay...');
      return await _sendViaMailRelay(
          recipients, subject, html, text, attachments);
    }

    try {
      print('=== SENDING VIA DIRECT SMTP ===');
      print('SMTP Host: $_smtpHost');
      print('SMTP Port: $_smtpPort');
      print('SMTP User: $_smtpUser');
      print('Recipients: ${recipients.join(", ")}');

      // Create SMTP server configuration
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        ssl: false,
        allowInsecure: true,
        username: _smtpUser,
        password: _smtpPass,
      );

      // Create the email message
      final message = Message()
        ..from = const Address(_smtpUser, _fromName)
        ..recipients.addAll(recipients)
        ..subject = subject
        ..html = html
        ..text = text;

      // Add attachments
      for (final file in attachments) {
        try {
          if (await file.exists()) {
            final attachment = FileAttachment(file);
            message.attachments.add(attachment);
            print('Added attachment: ${_getFileName(file.path)}');
          }
        } catch (e) {
          print('Warning: Could not attach file ${file.path}: $e');
        }
      }

      // Send the email
      print('Attempting to send email via SMTP...');
      final sendReport = await send(message, smtpServer);
      print('✅ Email sent successfully: ${sendReport.toString()}');
      return true;
    } catch (e, stackTrace) {
      print('❌ === DIRECT SMTP ERROR ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Full error details:');
      if (e is SocketException) {
        print('  Socket Exception - Connection issue');
        print('  Address: ${e.address}');
        print('  Port: ${e.port}');
        print('  OS Error: ${e.osError}');
      } else if (e is MailerException) {
        print('  Mailer Exception: ${e.message}');
      }
      print('Stack trace: $stackTrace');
      print('========================');
      return false;
    }
  }

  // Send email via HTTP mail relay (fallback for web platform)
  static Future<bool> _sendViaMailRelay(List<String> recipients, String subject,
      String html, String text, List<File> attachments) async {
    try {
      print('=== SENDING VIA HTTP MAIL RELAY ===');
      print('Mail Relay URL: $_mailRelayUrl/send-assessment');
      print('Recipients: ${recipients.join(", ")}');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_mailRelayUrl/send-assessment'),
      );

      // Add API key header if configured
      if (_mailRelayApiKey != 'YOUR_MAIL_RELAY_API_KEY') {
        request.headers['x-api-key'] = _mailRelayApiKey;
      }

      // Add form fields
      request.fields['subject'] = subject;
      request.fields['html'] = html;
      request.fields['text'] = text;
      request.fields['to'] = recipients.join(', ');

      // Add attachments
      for (final file in attachments) {
        try {
          final bytes = await file.readAsBytes();
          final fileName = _getFileName(file.path);
          request.files.add(http.MultipartFile.fromBytes(
            'attachment',
            bytes,
            filename: fileName,
          ));
          print('Added attachment: $fileName');
        } catch (e) {
          print('Warning: Could not attach file ${file.path}: $e');
        }
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('Mail Relay response: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('Mail Relay error response: $responseBody');
        return false;
      }

      final result = jsonDecode(responseBody);
      return result['success'] == true;
    } catch (e, stackTrace) {
      print('=== MAIL RELAY ERROR ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Stack trace: $stackTrace');
      print('=======================');
      return false;
    }
  }

  // Log email locally
  static void _logEmail(
      String type, List<String> to, String subject, bool success,
      {String? assessmentId, int? score}) {
    final logEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
      'from': _fromEmail,
      'to': to,
      'subject': subject,
      'status': success ? 'sent' : 'failed',
      'simulation': _simulationMode,
      'provider': _provider.toString(),
      if (assessmentId != null) 'assessment_id': assessmentId,
      if (score != null) 'score': score,
    };
    _emailLog.add(logEntry);
  }
}
