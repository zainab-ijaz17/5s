import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/submitted_assessment.dart';
import '../state/app_state.dart';
import '../util/assessment_submit_payload.dart';
import 'api_service.dart';
import 'assessment_draft_service.dart';
import 'assessment_service.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';

class SyncResult {
  final int syncedCount;
  final int failedCount;
  final String? lastError;
  final bool? emailSent;
  final String? emailError;
  /// True when email was started in the background (does not block submit).
  final bool emailQueued;

  const SyncResult({
    this.syncedCount = 0,
    this.failedCount = 0,
    this.lastError,
    this.emailSent,
    this.emailError,
    this.emailQueued = false,
  });
}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final AssessmentService _assessmentService = AssessmentService();

  bool _syncing = false;
  bool _resyncAfterCurrent = false;
  Timer? _debounceTimer;
  static const int _uploadBatchSize = 4;

  bool get isSyncing => _syncing;

  /// Debounce rapid connectivity events so sync does not block the app/API.
  void scheduleSync(AppState appState) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_runSync(appState));
    });
  }

  Future<void> _runSync(AppState appState) async {
    final result = await syncPendingAssessments(appState);
    if (result.failedCount > 0 && result.lastError != null) {
      debugPrint('Background sync failed: ${result.lastError}');
    }
  }

  Future<SyncResult> syncPendingAssessments(AppState appState) async {
    if (_syncing) {
      _resyncAfterCurrent = true;
      return const SyncResult(lastError: 'Sync already in progress');
    }
    if (!await ConnectivityService.instance.isOnline()) {
      return const SyncResult(lastError: 'No internet connection');
    }

    final pending =
        appState.assessments.where((a) => a.pendingSync).toList(growable: false);
    if (pending.isEmpty) return const SyncResult();

    _syncing = true;
    appState.setSyncState(inProgress: true, error: null, progress: null);

    var syncedCount = 0;
    var failedCount = 0;
    String? lastError;
    var emailQueued = false;

    try {
      await _ensureAuthForSync();

      for (final assessment in pending) {
        try {
          final current = _findAssessment(appState, assessment.id) ?? assessment;

          if (await _assessmentService.existsOnServer(current.id)) {
            appState.markAssessmentSynced(current.id);
            syncedCount++;
            continue;
          }

          final localPathsBeforeUpload = <String>[];
          for (final item in current.items) {
            final single = item['imagePath']?.toString();
            if (single != null && single.isNotEmpty) {
              localPathsBeforeUpload.add(single);
            }
            final raw = item['imagePaths'];
            if (raw is List) {
              localPathsBeforeUpload
                  .addAll(raw.map((e) => e.toString()).where((e) => e.isNotEmpty));
            }
          }

          final items =
              await _buildItemsWithUploadedImages(appState, current);
          final latest = _findAssessment(appState, current.id) ?? current;
          final payload =
              AssessmentSubmitPayload.fromAssessment(latest, items: items);

          final uploadedUrlCount = items.fold<int>(0, (sum, item) {
            final urls = item['imageUrls'];
            if (urls is! List) return sum;
            return sum +
                urls.map((e) => e.toString()).where((e) => e.isNotEmpty).length;
          });
          debugPrint(
            'Sync: assessment ${latest.id} submitting with '
            '$uploadedUrlCount image URL(s)',
          );

          appState.setSyncState(
            inProgress: true,
            error: null,
            progress: 'Submitting assessment to server...',
          );

          final submitRes =
              await ApiService.post('/assessments/submit', payload);
          if (!_submitResponseConfirmed(submitRes, latest.id)) {
            throw Exception(
              'Server did not confirm assessment was saved to the database.',
            );
          }
          appState.markAssessmentSynced(latest.id);
          syncedCount++;

          await AssessmentDraftService.instance
              .cleanupDraftImagesForPaths(localPathsBeforeUpload);

          // Email is handled by the API asynchronously (image links, no big
          // device SMTP attachments).
          emailQueued = true;
        } catch (e, st) {
          if (await _shouldMarkSyncedDespiteError(assessment.id, e)) {
            appState.markAssessmentSynced(assessment.id);
            syncedCount++;
            debugPrint(
              'Sync: assessment ${assessment.id} already on server; marked synced',
            );
            continue;
          }

          failedCount++;
          lastError = _humanizeSyncError(e, assessment.id);
          debugPrint('Sync failed for ${assessment.id}: $e\n$st');
        }
      }
    } catch (e, st) {
      lastError = _humanizeSyncError(e, null);
      debugPrint('Sync aborted: $e\n$st');
      failedCount = pending.length - syncedCount;
    } finally {
      _syncing = false;
      appState.setSyncState(
        inProgress: false,
        error: failedCount > 0 ? lastError : null,
        progress: null,
      );

      if (_resyncAfterCurrent) {
        _resyncAfterCurrent = false;
        unawaited(syncPendingAssessments(appState));
      }
    }

    return SyncResult(
      syncedCount: syncedCount,
      failedCount: failedCount,
      lastError: lastError,
      emailQueued: emailQueued,
    );
  }

  Future<bool> _shouldMarkSyncedDespiteError(
    String assessmentId,
    Object error,
  ) async {
    if (_looksLikeAlreadySubmitted(error)) return true;
    return _assessmentService.existsOnServer(assessmentId);
  }

  Future<void> _ensureAuthForSync() async {
    final token = await ApiService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not logged in. Sign in again to sync assessments.');
    }

    try {
      await AuthService().ensureValidAccessToken();
    } catch (e) {
      final token = await ApiService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Not logged in. Sign in again to sync assessments.');
      }
      throw Exception(
        'Session expired. Please sign out and sign in again, then retry sync.',
      );
    }
  }

  SubmittedAssessment? _findAssessment(AppState appState, String id) {
    for (final assessment in appState.assessments) {
      if (assessment.id == id) return assessment;
    }
    return null;
  }

  bool _submitResponseConfirmed(dynamic submitRes, String expectedId) {
    if (submitRes is! Map) return false;
    final serverId = submitRes['id']?.toString();
    return serverId != null && serverId.isNotEmpty && serverId == expectedId;
  }

  bool _looksLikeAlreadySubmitted(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('unique constraint') ||
        message.contains('already exists') ||
        message.contains('duplicate') ||
        message.contains('p2002') ||
        message.contains('409') ||
        message.contains('(500)') && message.contains('unique');
  }

  String _humanizeSyncError(Object error, String? assessmentId) {
    final prefix =
        assessmentId != null ? 'Assessment $assessmentId: ' : 'Sync: ';
    final message = error.toString();
    final lower = message.toLowerCase();

    // Reverse proxies / Cloudflare often return HTML 403/502 pages.
    if (lower.contains('just a moment') ||
        lower.contains('cloudflare') ||
        lower.contains('cf-ray') ||
        lower.contains('502') ||
        lower.contains('gateway or proxy') ||
        (lower.contains('<!doctype html') &&
            (lower.contains('(403)') || lower.contains('(502)')))) {
      return '${prefix}API gateway unavailable (502/403). '
          'The Nest server behind 5s-api.packagesgroup.com needs a restart, '
          'or Cloudflare is blocking the request.';
    }

    if (message.contains('401') || lower.contains('unauthorized')) {
      return '${prefix}Session expired. Please sign in again.';
    }
    if (message.contains('403')) {
      return '${prefix}Upload blocked (HTTP 403). '
          'Sign out/in and retry. If it continues, the API/WAF is rejecting the request.';
    }
    if (message.contains('500')) {
      return '${prefix}Server error during upload. Will retry automatically.';
    }
    if (lower.contains('forbidden') || lower.contains('should not exist')) {
      return '${prefix}Server rejected payload. Update the app.';
    }
    if (lower.contains('upload failed')) {
      return '${prefix}Image upload failed. Check connection and retry.';
    }

    return '$prefix${message.replaceFirst('Exception: ', '')}';
  }

  Future<List<Map<String, dynamic>>> _buildItemsWithUploadedImages(
    AppState appState,
    SubmittedAssessment assessment,
  ) async {
    final items = assessment.items
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: true);

    final totalPending = await _countPendingLocalImages(items);
    var uploadedCount = 0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];

      final urls = <String>[];
      final existingUrls = item['imageUrls'];
      if (existingUrls is List) {
        urls.addAll(
          existingUrls.map((e) => e.toString()).where((e) => e.isNotEmpty),
        );
      }

      final pendingFiles = <File>[];
      final pendingPaths = <String>[];
      final single = item['imagePath']?.toString();
      if (single != null && single.isNotEmpty) pendingPaths.add(single);
      final rawPaths = item['imagePaths'];
      if (rawPaths is List) {
        pendingPaths.addAll(
          rawPaths.map((e) => e.toString()).where((e) => e.isNotEmpty),
        );
      }

      for (final p in pendingPaths) {
        if (p.startsWith('http://') || p.startsWith('https://')) {
          if (!urls.contains(p)) urls.add(p);
          continue;
        }
        final file = File(p);
        if (await file.exists()) {
          pendingFiles.add(file);
        } else {
          debugPrint(
            'Sync: local image missing for assessment ${assessment.id} '
            'question ${i + 1}: $p',
          );
        }
      }

      if (pendingFiles.isEmpty) {
        if (pendingPaths.any((p) =>
                !p.startsWith('http://') && !p.startsWith('https://')) &&
            urls.isEmpty) {
          throw Exception(
            'Photo file(s) for question ${i + 1} were deleted before upload. '
            'Please re-open the assessment, add the photo(s) again, and submit.',
          );
        }
        item['imageUrls'] = urls;
        items[i] = item;
        continue;
      }

      final uploaded = await _uploadImages(
        assessmentId: assessment.id,
        questionIndex: i,
        files: pendingFiles,
        onBatchComplete: (batchCount) {
          uploadedCount += batchCount;
          if (totalPending > 0) {
            appState.setSyncState(
              inProgress: true,
              error: null,
              progress:
                  'Uploading photos ($uploadedCount/$totalPending)...',
            );
          }
        },
      );

      for (final url in uploaded) {
        if (!urls.contains(url)) urls.add(url);
      }

      final uploadedPaths = pendingFiles.map((file) => file.path).toSet();
      final remainingPaths =
          pendingPaths.where((path) => !uploadedPaths.contains(path)).toList();

      item['imageUrls'] = urls;
      item['imagePaths'] = remainingPaths;
      if (remainingPaths.isEmpty) {
        item.remove('imagePath');
      }
      items[i] = item;

      appState.updateSubmittedAssessment(
        assessment.copyWith(items: List<Map<String, dynamic>>.from(items)),
      );
    }

    return items;
  }

  Future<int> _countPendingLocalImages(List<Map<String, dynamic>> items) async {
    var count = 0;
    for (final item in items) {
      final paths = <String>[];
      final single = item['imagePath']?.toString();
      if (single != null && single.isNotEmpty) paths.add(single);
      final rawPaths = item['imagePaths'];
      if (rawPaths is List) {
        paths.addAll(
          rawPaths.map((e) => e.toString()).where((e) => e.isNotEmpty),
        );
      }

      for (final p in paths) {
        if (p.startsWith('http://') || p.startsWith('https://')) continue;
        if (await File(p).exists()) count++;
      }
    }
    return count;
  }

  Future<List<String>> _uploadImages({
    required String assessmentId,
    required int questionIndex,
    required List<File> files,
    void Function(int batchCount)? onBatchComplete,
  }) async {
    final urls = <String>[];
    for (var start = 0; start < files.length; start += _uploadBatchSize) {
      final end = (start + _uploadBatchSize > files.length)
          ? files.length
          : start + _uploadBatchSize;
      final batch = files.sublist(start, end);

      final response = await ApiService.uploadFiles('/uploads/images', batch);
      final uploaded = (response['files'] as List<dynamic>? ?? <dynamic>[]);
      if (uploaded.length < batch.length) {
        throw Exception(
          'Upload failed for question ${questionIndex + 1}: '
          'expected ${batch.length} file(s), got ${uploaded.length}',
        );
      }

      for (final entry in uploaded) {
        final map = Map<String, dynamic>.from(entry as Map);
        final urlOrPath = map['url']?.toString() ?? '';
        if (urlOrPath.isEmpty) {
          throw Exception('Upload response missing URL');
        }
        urls.add(ApiService.resolveUrl(urlOrPath));
      }

      onBatchComplete?.call(batch.length);
    }
    return urls;
  }
}
