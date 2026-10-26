import 'gemba_observation_status.dart';

class GembaObservation {
  final String id;
  final String title;
  final String location;
  final String category;
  final String status;
  final String assignedEmployeeNumber;
  final String? assignedEmployeeName;
  final String createdByEmployeeNumber;
  final String? createdByName;
  final String remarks;
  final String company;
  final String? bu;
  final String? section;
  final String? machineValue;
  final List<String>? _photoPaths;
  final int? _storedPhotoCount;
  final String? afterRemarks;
  final List<String>? _afterPhotoPaths;
  final String? completedByEmployeeNumber;
  final String? completedByName;
  final DateTime? completedAt;
  final DateTime createdAt;

  GembaObservation({
    required this.id,
    required this.title,
    required this.location,
    required this.category,
    required this.status,
    required this.assignedEmployeeNumber,
    this.assignedEmployeeName,
    required this.createdByEmployeeNumber,
    this.createdByName,
    required this.remarks,
    required this.company,
    this.bu,
    this.section,
    this.machineValue,
    List<String>? photoPaths,
    int? storedPhotoCount,
    this.afterRemarks,
    List<String>? afterPhotoPaths,
    this.completedByEmployeeNumber,
    this.completedByName,
    this.completedAt,
    required this.createdAt,
  })  : _photoPaths = photoPaths,
        _storedPhotoCount = storedPhotoCount,
        _afterPhotoPaths = afterPhotoPaths;

  List<String> get photoPaths {
    final paths = _photoPaths;
    if (paths == null || paths.isEmpty) return <String>[];
    return List<String>.from(paths);
  }

  List<String> get afterPhotoPaths {
    final paths = _afterPhotoPaths;
    if (paths == null || paths.isEmpty) return <String>[];
    return List<String>.from(paths);
  }

  int get storedPhotoCount => _storedPhotoCount ?? 0;

  int get photoCount =>
      photoPaths.isNotEmpty ? photoPaths.length : storedPhotoCount;

  bool get isDone => GembaObservationStatus.isDone(status);

  bool isAssignedTo(String employeeNumber) {
    final mine = employeeNumber.trim();
    if (mine.isEmpty) return false;
    return assignedEmployeeNumber.trim() == mine;
  }

  factory GembaObservation.fromJson(Map<String, dynamic> json) {
    return GembaObservation(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      status: GembaObservationStatus.normalize(json['status']?.toString()),
      assignedEmployeeNumber:
          (json['assignedEmployeeNumber'] ?? '').toString(),
      assignedEmployeeName: json['assignedEmployeeName']?.toString(),
      createdByEmployeeNumber:
          (json['createdByEmployeeNumber'] ?? '').toString(),
      createdByName: json['createdByName']?.toString(),
      remarks: (json['remarks'] ?? '').toString(),
      company: (json['company'] ?? '').toString(),
      bu: json['bu']?.toString(),
      section: json['section']?.toString(),
      machineValue: json['machineValue']?.toString(),
      photoPaths: parsePhotoPaths(json['photoPaths']),
      storedPhotoCount: parseStoredPhotoCount(json['photoCount']),
      afterRemarks: json['afterRemarks']?.toString(),
      afterPhotoPaths: parsePhotoPaths(json['afterPhotoPaths']),
      completedByEmployeeNumber:
          json['completedByEmployeeNumber']?.toString(),
      completedByName: json['completedByName']?.toString(),
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static List<String> parsePhotoPaths(dynamic raw) {
    if (raw == null) return <String>[];
    if (raw is! List) return <String>[];

    final paths = <String>[];
    for (final entry in raw) {
      if (entry == null) continue;
      final path = entry.toString().trim();
      if (path.isNotEmpty) paths.add(path);
    }
    return paths;
  }

  static int parseStoredPhotoCount(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  GembaObservation normalized() => GembaObservation.fromJson(toJson());

  GembaObservation copyWith({
    String? status,
    String? afterRemarks,
    List<String>? afterPhotoPaths,
    String? completedByEmployeeNumber,
    String? completedByName,
    DateTime? completedAt,
  }) {
    return GembaObservation(
      id: id,
      title: title,
      location: location,
      category: category,
      status: status ?? this.status,
      assignedEmployeeNumber: assignedEmployeeNumber,
      assignedEmployeeName: assignedEmployeeName,
      createdByEmployeeNumber: createdByEmployeeNumber,
      createdByName: createdByName,
      remarks: remarks,
      company: company,
      bu: bu,
      section: section,
      machineValue: machineValue,
      photoPaths: photoPaths,
      storedPhotoCount: storedPhotoCount,
      afterRemarks: afterRemarks ?? this.afterRemarks,
      afterPhotoPaths: afterPhotoPaths ?? this.afterPhotoPaths,
      completedByEmployeeNumber:
          completedByEmployeeNumber ?? this.completedByEmployeeNumber,
      completedByName: completedByName ?? this.completedByName,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'location': location,
        'category': category,
        'status': GembaObservationStatus.normalize(status),
        'assignedEmployeeNumber': assignedEmployeeNumber,
        'assignedEmployeeName': assignedEmployeeName,
        'createdByEmployeeNumber': createdByEmployeeNumber,
        'createdByName': createdByName,
        'remarks': remarks,
        'company': company,
        'bu': bu,
        'section': section,
        'machineValue': machineValue,
        'photoPaths': photoPaths,
        'photoCount': photoCount,
        'afterRemarks': afterRemarks,
        'afterPhotoPaths': afterPhotoPaths,
        'completedByEmployeeNumber': completedByEmployeeNumber,
        'completedByName': completedByName,
        'completedAt': completedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}
