class AssessmentItemUtil {
  static bool parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString().toLowerCase() == 'true';
  }

  static int parseScore(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime parseAssessmentDate(Map<String, dynamic> json) {
    for (final key in ['date', 'createdAt', 'updatedAt']) {
      final raw = json[key];
      if (raw == null) continue;
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  static List<Map<String, dynamic>> parseItems(dynamic raw) {
    if (raw is! List) return [];

    final items = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      items.add(normalizeItem(Map<String, dynamic>.from(entry)));
    }
    return items;
  }

  static Map<String, dynamic> normalizeItem(Map<String, dynamic> item) {
    final normalized = Map<String, dynamic>.from(item);

    final questionRaw = normalized['question'];
    if (questionRaw is Map) {
      final questionMap = Map<String, dynamic>.from(questionRaw);
      normalized['question'] = questionMap['question']?.toString() ??
          questionMap['text']?.toString() ??
          '';
      normalized['category'] ??= questionMap['category']?.toString();
      normalized['details'] ??= questionMap['details']?.toString();
      normalized['questionId'] ??= questionMap['id']?.toString();
    } else {
      normalized['question'] = questionRaw?.toString() ?? '';
    }

    normalized['answer'] = normalized['answer']?.toString() ?? 'N/A';
    normalized['remarks'] = normalized['remarks']?.toString() ?? '';
    normalized['isFlagged'] = parseBool(normalized['isFlagged']);

    final imageUrls = <String>[];
    final existingUrls = normalized['imageUrls'];
    if (existingUrls is List) {
      imageUrls.addAll(
        existingUrls.map((e) => e.toString()).where((e) => e.isNotEmpty),
      );
    }

    final attachments = normalized['attachments'];
    if (attachments is List) {
      for (final attachment in attachments) {
        if (attachment is! Map) continue;
        final url = attachment['url']?.toString();
        if (url != null && url.isNotEmpty && !imageUrls.contains(url)) {
          imageUrls.add(url);
        }
      }
    }

    if (imageUrls.isNotEmpty) {
      normalized['imageUrls'] = imageUrls;
    }

    return normalized;
  }

  static List<String> imagePathsFromItem(Map<String, dynamic> item) {
    final imageList = <String>[];

    final imageUrlsRaw = item['imageUrls'];
    if (imageUrlsRaw is List) {
      imageList.addAll(
        imageUrlsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty),
      );
    }

    final legacySingle = item['imagePath']?.toString();
    if (legacySingle != null && legacySingle.isNotEmpty) {
      imageList.add(legacySingle);
    }

    final imagePathsRaw = item['imagePaths'];
    if (imagePathsRaw is List) {
      imageList.addAll(
        imagePathsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty),
      );
    }

    return imageList;
  }

  static bool itemsMissingQuestionText(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return true;
    return items.every((item) => (item['question']?.toString() ?? '').isEmpty);
  }
}
