import '../models/submitted_assessment.dart';
import 'assessment_item_util.dart';

class AssessmentSubmitPayload {
  static const _allowedTopLevelKeys = {
    'id',
    'company',
    'bu',
    'section',
    'auditorName',
    'auditeeName',
    'auditorEmail',
    'auditeeEmail',
    'userName',
    'employeeId',
    'score',
    'isFlagged',
    'followUpDueAt',
    'followUpSent',
    'resolved',
    'resolvedAt',
    'resolvedBy',
    'date',
  };

  /// Builds a payload accepted by POST /assessments/submit (NestJS whitelist).
  static Map<String, dynamic> fromAssessment(
    SubmittedAssessment assessment, {
    List<Map<String, dynamic>>? items,
  }) {
    final raw = assessment.toJson();
    final payload = <String, dynamic>{};

    for (final key in _allowedTopLevelKeys) {
      final value = raw[key];
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      payload[key] = value;
    }

    final sourceItems = items ?? assessment.items;
    payload['items'] = sourceItems.map(cleanItem).toList();
    return payload;
  }

  static Map<String, dynamic> cleanItem(Map<String, dynamic> item) {
    final normalized = AssessmentItemUtil.normalizeItem(item);

    final imageUrls = <String>[];
    final imageUrlsRaw = normalized['imageUrls'];
    if (imageUrlsRaw is List) {
      imageUrls.addAll(
        imageUrlsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty),
      );
    }

    // Also accept any http(s) values left in imagePaths.
    final imagePathsRaw = normalized['imagePaths'];
    if (imagePathsRaw is List) {
      for (final raw in imagePathsRaw) {
        final path = raw.toString();
        if ((path.startsWith('http://') || path.startsWith('https://')) &&
            !imageUrls.contains(path)) {
          imageUrls.add(path);
        }
      }
    }

    final cleaned = <String, dynamic>{
      'question': normalized['question']?.toString() ?? '',
      'answer': normalized['answer']?.toString() ?? 'N/A',
      'remarks': normalized['remarks']?.toString() ?? '',
      'isFlagged': normalized['isFlagged'] == true,
    };

    // Send both shapes so Nest Attachment rows are always created.
    if (imageUrls.isNotEmpty) {
      cleaned['imageUrls'] = imageUrls;
      cleaned['attachments'] =
          imageUrls.map((url) => <String, String>{'url': url}).toList();
    }

    return cleaned;
  }
}
