
class SubmittedAssessment {
  final String id;
  final String company;
  final String? bu;
  final String? section;
  final String auditorName;
  final String auditeeName;
  final String? auditorEmail; // New field
  final String? auditeeEmail; // New field
  final String? userName; // Name of person who took assessment
  final int? employeeId; // Employee ID of person who took assessment
  final DateTime date;
  final List<Map<String, dynamic>>
      items; // [{question, answer, remarks, imagePaths, isFlagged}]
  final int score; // 0-100
  final bool isFlagged; // any item flagged
  final DateTime? followUpDueAt; // if flagged, schedule after 14 days
  final bool followUpSent; // whether follow-up email has been sent
  final bool resolved; // whether flagged issues have been addressed
  final DateTime? resolvedAt; // when it was marked resolved
  final String? resolvedBy; // user who resolved

  SubmittedAssessment({
    required this.id,
    required this.company,
    required this.auditorName,
    required this.auditeeName,
    required this.date,
    required this.items,
    required this.score,
    required this.isFlagged,
    this.bu,
    this.section,
    this.auditorEmail, // New parameter
    this.auditeeEmail, // New parameter
    this.userName, // New parameter
    this.employeeId, // New parameter
    this.followUpDueAt,
    this.followUpSent = false,
    this.resolved = false,
    this.resolvedAt,
    this.resolvedBy,
  });

  // Add copyWith method if you don't have one
  SubmittedAssessment copyWith({
    String? id,
    String? company,
    String? bu,
    String? section,
    String? auditorName,
    String? auditeeName,
    String? auditorEmail,
    String? auditeeEmail,
    String? userName,
    int? employeeId,
    DateTime? date,
    List<Map<String, dynamic>>? items,
    int? score,
    bool? isFlagged,
    DateTime? followUpDueAt,
    bool? followUpSent,
    bool? resolved,
    DateTime? resolvedAt,
    String? resolvedBy,
  }) {
    return SubmittedAssessment(
      id: id ?? this.id,
      company: company ?? this.company,
      bu: bu ?? this.bu,
      section: section ?? this.section,
      auditorName: auditorName ?? this.auditorName,
      auditeeName: auditeeName ?? this.auditeeName,
      auditorEmail: auditorEmail ?? this.auditorEmail,
      auditeeEmail: auditeeEmail ?? this.auditeeEmail,
      userName: userName ?? this.userName,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      items: items ?? List.from(this.items),
      score: score ?? this.score,
      isFlagged: isFlagged ?? this.isFlagged,
      followUpDueAt: followUpDueAt ?? this.followUpDueAt,
      followUpSent: followUpSent ?? this.followUpSent,
      resolved: resolved ?? this.resolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
    );
  }

  // Add toJson and fromJson if you need JSON serialization
  Map<String, dynamic> toJson() => {
        'id': id,
        'company': company,
        'bu': bu,
        'section': section,
        'auditorName': auditorName,
        'auditeeName': auditeeName,
        'auditorEmail': auditorEmail,
        'auditeeEmail': auditeeEmail,
        'userName': userName,
        'employeeId': employeeId,
        'date': date.toIso8601String(),
        'items': items,
        'score': score,
        'isFlagged': isFlagged,
        'followUpDueAt': followUpDueAt?.toIso8601String(),
        'followUpSent': followUpSent,
        'resolved': resolved,
        'resolvedAt': resolvedAt?.toIso8601String(),
        'resolvedBy': resolvedBy,
      };

  factory SubmittedAssessment.fromJson(Map<String, dynamic> json) {
    try {
      final dynamic employeeIdRaw = json['employeeId'];
      final int? parsedEmployeeId = employeeIdRaw is int
          ? employeeIdRaw
          : int.tryParse(employeeIdRaw?.toString() ?? '');

      return SubmittedAssessment(
        id: json['id']?.toString() ?? '',
        company: json['company']?.toString() ?? '',
        bu: json['bu']?.toString(),
        section: json['section']?.toString(),
        auditorName: json['auditorName']?.toString() ?? '',
        auditeeName: json['auditeeName']?.toString() ?? '',
        auditorEmail: json['auditorEmail']?.toString(),
        auditeeEmail: json['auditeeEmail']?.toString(),
        userName: json['userName']?.toString(),
        employeeId: parsedEmployeeId,
        date: json['date'] != null
            ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
            : DateTime.now(),
        items: json['items'] != null
            ? List<Map<String, dynamic>>.from(json['items'])
            : [],
        score: json['score']?.toInt() ?? 0,
        isFlagged: json['isFlagged']?.toString().toLowerCase() == 'true',
        followUpDueAt: json['followUpDueAt'] != null
            ? DateTime.tryParse(json['followUpDueAt'].toString())
            : null,
        followUpSent: json['followUpSent']?.toString().toLowerCase() == 'true',
        resolved: json['resolved']?.toString().toLowerCase() == 'true',
        resolvedAt: json['resolvedAt'] != null
            ? DateTime.tryParse(json['resolvedAt'].toString())
            : null,
        resolvedBy: json['resolvedBy']?.toString(),
      );
    } catch (e) {
      print('Error parsing SubmittedAssessment from JSON: $e');
      rethrow;
    }
  }
}
