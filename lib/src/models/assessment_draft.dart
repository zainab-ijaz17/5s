class AssessmentDraft {
  final String id;
  final String? userId;
  final int? employeeId;
  final String company;
  final String? bu;
  final String? section;
  final String? auditorName;
  final String? auditeeName;
  final DateTime startedAt;
  final DateTime updatedAt;
  final int totalQuestions;
  final Map<int, String> answers;
  final Map<int, String> comments;
  final Map<int, List<String>> imagePaths;

  const AssessmentDraft({
    required this.id,
    this.userId,
    this.employeeId,
    required this.company,
    this.bu,
    this.section,
    this.auditorName,
    this.auditeeName,
    required this.startedAt,
    required this.updatedAt,
    required this.totalQuestions,
    this.answers = const {},
    this.comments = const {},
    this.imagePaths = const {},
  });

  int get answeredCount => answers.length;

  double get progressFraction =>
      totalQuestions > 0 ? answeredCount / totalQuestions : 0.0;

  bool get hasProgress =>
      answers.isNotEmpty ||
      comments.values.any((c) => c.trim().isNotEmpty) ||
      imagePaths.values.any((paths) => paths.isNotEmpty);

  AssessmentDraft copyWith({
    String? id,
    String? userId,
    int? employeeId,
    String? company,
    String? bu,
    String? section,
    String? auditorName,
    String? auditeeName,
    DateTime? startedAt,
    DateTime? updatedAt,
    int? totalQuestions,
    Map<int, String>? answers,
    Map<int, String>? comments,
    Map<int, List<String>>? imagePaths,
  }) {
    return AssessmentDraft(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      employeeId: employeeId ?? this.employeeId,
      company: company ?? this.company,
      bu: bu ?? this.bu,
      section: section ?? this.section,
      auditorName: auditorName ?? this.auditorName,
      auditeeName: auditeeName ?? this.auditeeName,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      answers: answers ?? Map<int, String>.from(this.answers),
      comments: comments ?? Map<int, String>.from(this.comments),
      imagePaths: imagePaths ??
          this.imagePaths.map((k, v) => MapEntry(k, List<String>.from(v))),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'employeeId': employeeId,
        'company': company,
        'bu': bu,
        'section': section,
        'auditorName': auditorName,
        'auditeeName': auditeeName,
        'startedAt': startedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'totalQuestions': totalQuestions,
        'answers': answers.map((k, v) => MapEntry(k.toString(), v)),
        'comments': comments.map((k, v) => MapEntry(k.toString(), v)),
        'imagePaths': imagePaths.map(
          (k, v) => MapEntry(k.toString(), v),
        ),
      };

  factory AssessmentDraft.fromJson(Map<String, dynamic> json) {
    final answersRaw = json['answers'];
    final commentsRaw = json['comments'];
    final imagesRaw = json['imagePaths'];

    final answers = <int, String>{};
    if (answersRaw is Map) {
      answersRaw.forEach((key, value) {
        final index = int.tryParse(key.toString());
        if (index != null) answers[index] = value.toString();
      });
    }

    final comments = <int, String>{};
    if (commentsRaw is Map) {
      commentsRaw.forEach((key, value) {
        final index = int.tryParse(key.toString());
        if (index != null) comments[index] = value.toString();
      });
    }

    final imagePaths = <int, List<String>>{};
    if (imagesRaw is Map) {
      imagesRaw.forEach((key, value) {
        final index = int.tryParse(key.toString());
        if (index == null || value is! List) return;
        imagePaths[index] =
            value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      });
    }

    return AssessmentDraft(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString(),
      employeeId: json['employeeId'] is int
          ? json['employeeId'] as int
          : int.tryParse(json['employeeId']?.toString() ?? ''),
      company: json['company']?.toString() ?? '',
      bu: json['bu']?.toString(),
      section: json['section']?.toString(),
      auditorName: json['auditorName']?.toString(),
      auditeeName: json['auditeeName']?.toString(),
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      totalQuestions: json['totalQuestions'] is int
          ? json['totalQuestions'] as int
          : int.tryParse(json['totalQuestions']?.toString() ?? '0') ?? 0,
      answers: answers,
      comments: comments,
      imagePaths: imagePaths,
    );
  }
}
