import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/assessment_draft.dart';

class AssessmentDraftService {
  AssessmentDraftService._();
  static final AssessmentDraftService instance = AssessmentDraftService._();

  static const String _storageKey = 'assessment_draft_v1';
  static const String _draftImagesFolder = 'assessment_draft_images';

  /// True while [AssessmentScreen] is open — suppresses home-page draft prompts.
  bool _assessmentScreenOpen = false;
  bool get isAssessmentScreenOpen => _assessmentScreenOpen;

  void setAssessmentScreenOpen(bool open) {
    _assessmentScreenOpen = open;
  }

  Future<Directory> _draftImagesRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_draftImagesFolder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _draftImagesDir(String draftId) async {
    final root = await _draftImagesRoot();
    final safeId = draftId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final dir = Directory('${root.path}/$safeId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  bool _isAlreadyInDraftStorage(String path, String draftDirPath) {
    return path.startsWith(draftDirPath);
  }

  String _extensionFor(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '.jpg';
    return name.substring(dot).toLowerCase();
  }

  /// Copies picker/temp files into app documents so photos survive app restarts.
  Future<Map<int, List<String>>> persistImageFiles({
    required String draftId,
    required Map<int, List<File>> imageFiles,
  }) async {
    final draftDir = await _draftImagesDir(draftId);
    final durable = <int, List<String>>{};

    for (final entry in imageFiles.entries) {
      final index = entry.key;
      final files = entry.value;
      final kept = <String>[];

      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final sourcePath = file.path;
        if (sourcePath.isEmpty) continue;

        if (_isAlreadyInDraftStorage(sourcePath, draftDir.path)) {
          if (await File(sourcePath).exists()) {
            kept.add(sourcePath);
          }
          continue;
        }

        if (!await file.exists()) continue;

        final ext = _extensionFor(sourcePath);
        final destPath =
            '${draftDir.path}/q${index}_$i${DateTime.now().microsecondsSinceEpoch}$ext';
        try {
          final copied = await file.copy(destPath);
          kept.add(copied.path);
        } catch (_) {
          // Skip unreadable temp files rather than failing the whole draft.
        }
      }

      if (kept.isNotEmpty) durable[index] = kept;
    }

    // Drop orphaned files for question indexes no longer present.
    try {
      final expected = durable.values.expand((e) => e).toSet();
      await for (final entity in draftDir.list()) {
        if (entity is! File) continue;
        if (!expected.contains(entity.path)) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}

    return durable;
  }

  Future<void> _deleteDraftImages({String? draftId}) async {
    try {
      if (draftId != null && draftId.isNotEmpty) {
        final dir = await _draftImagesDir(draftId);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        return;
      }

      final root = await _draftImagesRoot();
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<void> saveDraft(AssessmentDraft draft) async {
    if (!draft.hasProgress) {
      await clearDraft();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(draft.toJson()));
  }

  Future<AssessmentDraft?> loadDraft({
    String? userId,
    int? employeeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final draft = AssessmentDraft.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (!draft.hasProgress) {
        await clearDraft();
        return null;
      }

      if (!_matchesUser(draft, userId: userId, employeeId: employeeId)) {
        return null;
      }

      // Keep only image paths that still exist on disk.
      final existingImages = <int, List<String>>{};
      draft.imagePaths.forEach((index, paths) {
        final kept = paths
            .where((p) => p.isNotEmpty && File(p).existsSync())
            .toList();
        if (kept.isNotEmpty) existingImages[index] = kept;
      });

      if (existingImages.length != draft.imagePaths.length ||
          existingImages.entries.any(
            (e) => e.value.length != (draft.imagePaths[e.key]?.length ?? 0),
          )) {
        final cleaned = draft.copyWith(imagePaths: existingImages);
        await prefs.setString(_storageKey, jsonEncode(cleaned.toJson()));
        return cleaned;
      }

      return draft;
    } catch (_) {
      await clearDraft();
      return null;
    }
  }

  Future<bool> hasDraft({
    String? userId,
    int? employeeId,
  }) async {
    final draft = await loadDraft(userId: userId, employeeId: employeeId);
    return draft != null;
  }

  Future<void> clearDraft({bool deleteImages = true}) async {
    String? draftId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        draftId = map['id']?.toString();
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);

    // On submit we must keep files until upload finishes; discard deletes them.
    if (deleteImages) {
      await _deleteDraftImages(draftId: draftId);
    }
  }

  /// Removes durable draft image folders after a successful server upload.
  Future<void> cleanupDraftImagesForPaths(Iterable<String> paths) async {
    final draftRoot = await _draftImagesRoot();
    final dirsToDelete = <String>{};

    for (final path in paths) {
      if (!path.startsWith(draftRoot.path)) continue;
      final file = File(path);
      final parent = file.parent;
      if (parent.path.startsWith(draftRoot.path) &&
          parent.path != draftRoot.path) {
        dirsToDelete.add(parent.path);
      }
    }

    for (final dirPath in dirsToDelete) {
      try {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  bool _matchesUser(
    AssessmentDraft draft, {
    String? userId,
    int? employeeId,
  }) {
    if (userId != null &&
        userId.isNotEmpty &&
        draft.userId != null &&
        draft.userId!.isNotEmpty) {
      return draft.userId == userId;
    }
    if (employeeId != null &&
        draft.employeeId != null &&
        draft.employeeId == employeeId) {
      return true;
    }
    return draft.userId == null && draft.employeeId == null;
  }
}
