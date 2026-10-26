import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves a PDF to disk and opens the platform share / save sheet.
class GembaPdfExportService {
  GembaPdfExportService._();

  static Future<void> share({
    required Uint8List bytes,
    required String filename,
    Rect? sharePositionOrigin,
  }) async {
    final safeName = filename.endsWith('.pdf') ? filename : '$filename.pdf';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf', name: safeName)],
      subject: safeName,
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
