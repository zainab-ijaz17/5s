import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';

/// Persists observation photos under app documents for offline viewing.
class GembaObservationPhotos {
  GembaObservationPhotos._();

  static Future<List<String>> persistPhotos({
    required String observationId,
    required List<XFile> photos,
    String filePrefix = 'photo',
  }) async {
    if (photos.isEmpty) return <String>[];

    final root = await getApplicationDocumentsDirectory();
    final obsDir = Directory('${root.path}/gemba_observations/$observationId');
    if (!await obsDir.exists()) {
      await obsDir.create(recursive: true);
    }

    final savedPaths = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final sourcePath = photos[i].path;
      final sourceName = sourcePath.split('/').last;
      final extension = sourceName.contains('.')
          ? '.${sourceName.split('.').last}'
          : '.jpg';
      final dest = File('${obsDir.path}/${filePrefix}_$i$extension');
      await File(sourcePath).copy(dest.path);
      savedPaths.add(dest.path);
    }
    return savedPaths;
  }

  static bool existsAt(String path) {
    if (isRemoteUrl(path)) return true;
    return File(path).existsSync();
  }

  static bool isRemoteUrl(String path) {
    final trimmed = path.trim();
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('/uploads/');
  }

  static String resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return ApiService.resolveUrl(path);
  }

  static Widget buildImage(
    String path, {
    BoxFit fit = BoxFit.cover,
    Widget? error,
  }) {
    if (isRemoteUrl(path)) {
      return Image.network(
        resolveUrl(path),
        fit: fit,
        errorBuilder: (_, __, ___) =>
            error ??
            Container(
              color: const Color(0xFFE2E8F0),
              child: const Icon(Icons.broken_image_outlined),
            ),
      );
    }

    return Image.file(
      File(path),
      fit: fit,
      errorBuilder: (_, __, ___) =>
          error ??
          Container(
            color: const Color(0xFFE2E8F0),
            child: const Icon(Icons.broken_image_outlined),
          ),
    );
  }
}
