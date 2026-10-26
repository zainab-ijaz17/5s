import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/gemba_demo_data.dart';
import '../models/gemba_observation_stats.dart';
import '../models/gemba_observation.dart';
import 'api_service.dart';
import 'gemba_session_service.dart';

enum GembaObservationFilter {
  all,
  assigned,
  assignedInProgress,
  inProgress,
  done,
}

class GembaObservationsService extends ChangeNotifier {
  GembaObservationsService._();
  static final GembaObservationsService instance = GembaObservationsService._();

  List<GembaObservation> _items = <GembaObservation>[];
  bool _loaded = false;
  String? _lastError;
  Future<void>? _loadInflight;

  bool get isLoaded => _loaded;
  String? get lastError => _lastError;
  int get totalCount => _items.length;

  List<GembaObservation> get items => List.unmodifiable(_items);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    if (_loadInflight != null) {
      await _loadInflight;
      return;
    }
    _loadInflight = _load();
    try {
      await _loadInflight;
    } finally {
      _loadInflight = null;
    }
  }

  Future<void> reload() async {
    _loaded = false;
    _loadInflight = null;
    await ensureLoaded();
  }

  Future<String> _requireToken() async {
    final session = await GembaSessionService.instance.loadSession();
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Sign in again to sync observations');
    }
    return token;
  }

  Future<void> _load() async {
    try {
      final token = await _requireToken();
      final response = await ApiService.get(
        '/gemba/observations',
        accessToken: token,
      );
      final list = _parseObservationList(response);
      _items = <GembaObservation>[];
      for (final row in list) {
        if (row is! Map) continue;
        try {
          _items.add(
            GembaObservation.fromJson(Map<String, dynamic>.from(row))
                .normalized(),
          );
        } catch (_) {
          // Skip malformed rows instead of failing the whole list.
        }
      }
      _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _lastError = null;
      _loaded = true;
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '');
      if (!_loaded) {
        _items = <GembaObservation>[];
      }
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<GembaObservation?> fetchById(String id) async {
    final token = await _requireToken();
    final response = await ApiService.get(
      '/gemba/observations/$id',
      accessToken: token,
    );
    if (response is! Map) return null;

    final observation = GembaObservation.fromJson(
      Map<String, dynamic>.from(response),
    ).normalized();

    final index = _items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _items[index] = observation;
    } else {
      _items = [observation, ...List<GembaObservation>.from(_items)];
    }
    _lastError = null;
    _loaded = true;
    notifyListeners();
    return observation;
  }

  List<dynamic> _parseObservationList(dynamic response) {
    if (response is List) return response;
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      for (final key in ['data', 'observations', 'results', 'items']) {
        final nested = map[key];
        if (nested is List) return nested;
      }
    }
    return const [];
  }

  Future<void> add(GembaObservation observation) async {
    await ensureLoaded();
    final token = await _requireToken();
    final beforePhotoUrls =
        await _uploadPhotoPaths(observation.photoPaths, token);

    final response = await ApiService.post(
      '/gemba/observations',
      {
        'title': observation.title,
        'location': observation.location,
        'category': observation.category,
        'assignedEmployeeNumber': observation.assignedEmployeeNumber,
        if (observation.assignedEmployeeName != null)
          'assignedEmployeeName': observation.assignedEmployeeName,
        'remarks': observation.remarks,
        'company': observation.company,
        if (observation.bu != null) 'bu': observation.bu,
        if (observation.section != null) 'section': observation.section,
        if (observation.machineValue != null)
          'machineValue': observation.machineValue,
        'beforePhotoUrls': beforePhotoUrls,
      },
      accessToken: token,
    );

    final saved = GembaObservation.fromJson(
      Map<String, dynamic>.from(response as Map),
    ).normalized();
    _items = [saved, ...List<GembaObservation>.from(_items)];
    notifyListeners();
  }

  Future<void> markAsDone({
    required String id,
    required String afterRemarks,
    required List<String> afterPhotoPaths,
    required String completedByEmployeeNumber,
    String? completedByName,
  }) async {
    await ensureLoaded();
    final token = await _requireToken();
    final afterPhotoUrls = await _uploadPhotoPaths(afterPhotoPaths, token);

    final response = await ApiService.patch(
      '/gemba/observations/$id/complete',
      {
        'afterRemarks': afterRemarks,
        'afterPhotoUrls': afterPhotoUrls,
      },
      accessToken: token,
    );

    final saved = GembaObservation.fromJson(
      Map<String, dynamic>.from(response as Map),
    ).normalized();
    final index = _items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _items[index] = saved;
    } else {
      _items = [saved, ...List<GembaObservation>.from(_items)];
    }
    notifyListeners();
  }

  GembaObservation? findById(String id) {
    for (final item in _items) {
      if (item.id == id) return item.normalized();
    }
    return null;
  }

  Future<List<String>> _uploadPhotoPaths(
    List<String> paths,
    String token,
  ) async {
    final remoteUrls = <String>[];
    final localFiles = <File>[];

    for (final path in paths) {
      if (_isRemoteUrl(path)) {
        remoteUrls.add(_resolvePhotoUrl(path));
        continue;
      }
      final file = File(path);
      if (file.existsSync()) {
        localFiles.add(file);
      }
    }

    if (localFiles.isEmpty) return remoteUrls;

    final response = await ApiService.uploadFiles(
      '/gemba/uploads/images',
      localFiles,
      accessToken: token,
    );
    final uploaded = _extractUploadUrls(response);
    return [...remoteUrls, ...uploaded];
  }

  List<String> _extractUploadUrls(dynamic response) {
    if (response is! Map) return const [];
    final files = response['files'];
    if (files is! List) return const [];

    final urls = <String>[];
    for (final entry in files) {
      if (entry is! Map) continue;
      final url = entry['url']?.toString();
      if (url == null || url.isEmpty) continue;
      urls.add(_resolvePhotoUrl(url));
    }
    return urls;
  }

  static bool _isRemoteUrl(String path) {
    final trimmed = path.trim();
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('/uploads/');
  }

  static String _resolvePhotoUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return ApiService.resolveUrl(path);
  }

  List<GembaObservation> filtered({
    required GembaObservationFilter filter,
    String? currentEmployeeNumber,
    String? bu,
    String? section,
    String? category,
  }) {
    Iterable<GembaObservation> results = _items;

    switch (filter) {
      case GembaObservationFilter.assigned:
        final mine = GembaDemoData.normalizeEmployeeNumber(currentEmployeeNumber);
        if (mine.isEmpty) return const [];
        results = results.where(
          (item) =>
              GembaDemoData.normalizeEmployeeNumber(
                item.assignedEmployeeNumber,
              ) ==
              mine,
        );
      case GembaObservationFilter.assignedInProgress:
        final mine = GembaDemoData.normalizeEmployeeNumber(currentEmployeeNumber);
        if (mine.isEmpty) return const [];
        results = results.where(
          (item) => item.isAssignedTo(mine) && !item.isDone,
        );
      case GembaObservationFilter.inProgress:
        results = results.where((item) => !item.isDone);
      case GembaObservationFilter.done:
        results = results.where((item) => item.isDone);
      case GembaObservationFilter.all:
        break;
    }

    return results
        .where(
          (item) => _matchesFilters(
            item,
            bu: bu,
            section: section,
            category: category,
          ),
        )
        .toList();
  }

  GembaObservationStats stats({
    String? currentEmployeeNumber,
    String? bu,
    String? section,
    String? category,
  }) {
    final mine = GembaDemoData.normalizeEmployeeNumber(currentEmployeeNumber);
    var assignedTotal = 0;
    var assignedInProgress = 0;
    var assignedDone = 0;
    var createdByMe = 0;
    var inProgress = 0;
    var done = 0;
    var total = 0;

    for (final item in _items) {
      if (!_matchesFilters(
        item,
        bu: bu,
        section: section,
        category: category,
      )) {
        continue;
      }
      total++;

      if (item.isDone) {
        done++;
      } else {
        inProgress++;
      }

      if (mine.isNotEmpty) {
        if (item.isAssignedTo(mine)) {
          assignedTotal++;
          if (item.isDone) {
            assignedDone++;
          } else {
            assignedInProgress++;
          }
        }
        if (item.createdByEmployeeNumber.trim() == mine) {
          createdByMe++;
        }
      }
    }

    return GembaObservationStats(
      total: total,
      inProgress: inProgress,
      done: done,
      assignedTotal: assignedTotal,
      assignedInProgress: assignedInProgress,
      assignedDone: assignedDone,
      createdByMe: createdByMe,
    );
  }

  static bool _matchesFilters(
    GembaObservation item, {
    String? bu,
    String? section,
    String? category,
  }) {
    if (bu != null && bu.isNotEmpty && (item.bu ?? '').trim() != bu) {
      return false;
    }
    if (section != null &&
        section.isNotEmpty &&
        (item.section ?? '').trim() != section) {
      return false;
    }
    if (category != null &&
        category.isNotEmpty &&
        item.category.trim() != category) {
      return false;
    }
    return true;
  }
}
