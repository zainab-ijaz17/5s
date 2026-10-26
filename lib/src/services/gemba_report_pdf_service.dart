import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/gemba_observation.dart';
import '../models/gemba_observation_status.dart';
import 'api_service.dart';
import 'gemba_observation_photos.dart';
import 'gemba_pdf_logo_loader.dart';

class GembaReportPdfService {
  GembaReportPdfService._();

  static const _brandDark = PdfColor.fromInt(0xFF006BA6);
  static const _brandPrimary = PdfColor.fromInt(0xFF008FD5);
  static const _brandLight = PdfColor.fromInt(0xFF4DB8E8);
  static const _brandTint = PdfColor.fromInt(0xFFE8F4FC);
  static const _slate = PdfColor.fromInt(0xFF64748B);
  static const _border = PdfColor.fromInt(0xFFD6EAF8);

  static Future<Uint8List> build({
    required List<GembaObservation> observations,
    String? company,
    String? bu,
    String? section,
    String? category,
    GembaReportStatusFilter statusFilter = GembaReportStatusFilter.all,
    required String accessToken,
  }) async {
    final imageCache = <String, pw.MemoryImage?>{};

    Future<pw.MemoryImage?> loadImage(String path) async {
      if (imageCache.containsKey(path)) return imageCache[path];
      final bytes = await _loadImageBytes(path, accessToken);
      if (bytes == null || bytes.isEmpty) {
        imageCache[path] = null;
        return null;
      }
      try {
        final image = pw.MemoryImage(bytes);
        imageCache[path] = image;
        return image;
      } catch (_) {
        imageCache[path] = null;
        return null;
      }
    }

    final doc = pw.Document(
      title: 'Digital Gemba Report',
      author: 'Packages Group',
    );

    final generatedAt = DateTime.now();
    final filterLine = _buildFilterLine(
      company: company,
      bu: bu,
      section: section,
      category: category,
      statusFilter: statusFilter,
    );
    final reportHeading = _buildReportHeading(
      company: company,
      bu: bu,
      section: section,
      category: category,
      statusFilter: statusFilter,
    );
    final logo = await GembaPdfLogoLoader.load(height: 80);

    final blocks = <pw.Widget>[];
    if (observations.isEmpty) {
      blocks.addAll([
        pw.SizedBox(height: 24),
        pw.Center(
          child: pw.Text(
            statusFilter.emptyMessage,
            style: pw.TextStyle(fontSize: 12, color: _slate),
          ),
        ),
      ]);
    } else {
      for (var i = 0; i < observations.length; i++) {
        blocks.add(
          await _observationBlock(
            index: i + 1,
            observation: observations[i],
            loadImage: loadImage,
          ),
        );
        if (i < observations.length - 1) {
          blocks.add(pw.SizedBox(height: 18));
        }
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 48),
        header: (context) => _pageHeader(
          filterLine: filterLine,
          reportHeading: reportHeading,
          reportTitle: statusFilter.reportTitle,
          generatedAt: generatedAt,
          isFirstPage: context.pageNumber == 1,
          logo: logo,
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Digital Gemba',
              style: pw.TextStyle(fontSize: 8, color: _brandPrimary),
            ),
            pw.Text(
              'Page ${context.pageNumber}',
              style: pw.TextStyle(fontSize: 9, color: _slate),
            ),
          ],
        ),
        build: (context) => blocks,
      ),
    );

    return doc.save();
  }

  static pw.Widget _pageHeader({
    required String filterLine,
    required String reportHeading,
    required String reportTitle,
    required DateTime generatedAt,
    required bool isFirstPage,
    pw.MemoryImage? logo,
  }) {
    if (!isFirstPage) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: _border, width: 1),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Digital Gemba - $reportTitle',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _brandPrimary,
              ),
            ),
            pw.Text(
              _formatDate(generatedAt),
              style: const pw.TextStyle(fontSize: 9, color: _slate),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(
          height: 112,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(
                flex: 65,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: pw.BoxDecoration(
                    gradient: const pw.LinearGradient(
                      colors: [_brandDark, _brandPrimary, _brandLight],
                    ),
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(10),
                      bottomLeft: pw.Radius.circular(10),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Digital Gemba',
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        reportTitle,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        filterLine,
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColor.fromInt(0xCCFFFFFF),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Generated ${_formatDate(generatedAt)}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColor.fromInt(0xB3FFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (logo != null)
                pw.Expanded(
                  flex: 35,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: _border, width: 1),
                      borderRadius: const pw.BorderRadius.only(
                        topRight: pw.Radius.circular(10),
                        bottomRight: pw.Radius.circular(10),
                      ),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.SizedBox(
                      height: 72,
                      child: pw.Image(
                        logo,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                reportHeading,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _brandDark,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                width: 72,
                height: 3,
                decoration: pw.BoxDecoration(
                  color: _brandPrimary,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  static Future<pw.Widget> _observationBlock({
    required int index,
    required GembaObservation observation,
    required Future<pw.MemoryImage?> Function(String path) loadImage,
  }) async {
    final sectionName =
        (observation.section?.trim().isNotEmpty == true)
            ? observation.section!.trim()
            : observation.location.trim();

    final beforeImages = await _columnImages(
      observation.photoPaths,
      loadImage,
    );
    final afterImages = await _columnImages(
      observation.afterPhotoPaths,
      loadImage,
    );

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 1),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const pw.BoxDecoration(
              color: _brandTint,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(10),
                topRight: pw.Radius.circular(10),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Observation #${_paddedNumber(index)}',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _brandDark,
                  ),
                ),
                pw.Text(
                  'Section: $sectionName',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _slate,
                  ),
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _photoColumn(
                    title: 'Before',
                    images: beforeImages,
                    remarks: observation.remarks,
                    accent: _brandDark,
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _photoColumn(
                    title: 'After',
                    images: afterImages,
                    remarks: observation.afterRemarks ?? '',
                    accent: _brandPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _photoColumn({
    required String title,
    required List<pw.Widget> images,
    required String remarks,
    required PdfColor accent,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              title,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          if (images.isEmpty)
            _placeholderImage()
          else
            ...images,
          pw.SizedBox(height: 8),
          pw.Text(
            'Remarks',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _slate,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            remarks.trim().isEmpty ? '-' : remarks.trim(),
            style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 1.35),
          ),
        ],
      ),
    );
  }

  static pw.Widget _placeholderImage() {
    return pw.Container(
      height: 120,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF4FAFE),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Text(
        'No image',
        style: pw.TextStyle(fontSize: 9, color: _slate),
      ),
    );
  }

  static Future<List<pw.Widget>> _columnImages(
    List<String> paths,
    Future<pw.MemoryImage?> Function(String path) loadImage,
  ) async {
    if (paths.isEmpty) return const [];

    final widgets = <pw.Widget>[];
    for (final path in paths) {
      final image = await loadImage(path);
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: image == null
              ? _placeholderImage()
              : pw.ClipRRect(
                  horizontalRadius: 6,
                  verticalRadius: 6,
                  child: pw.SizedBox(
                    height: 120,
                    child: pw.Image(
                      image,
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                ),
        ),
      );
    }
    return widgets;
  }

  static Future<Uint8List?> _loadImageBytes(
    String path,
    String accessToken,
  ) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;

    if (GembaObservationPhotos.isRemoteUrl(trimmed)) {
      try {
        final bytes = await ApiService.downloadBytes(
          trimmed,
          accessToken: accessToken,
        );
        return Uint8List.fromList(bytes);
      } catch (_) {
        return null;
      }
    }

    final file = File(trimmed);
    if (file.existsSync()) {
      try {
        return file.readAsBytes();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String _buildFilterLine({
    String? company,
    String? bu,
    String? section,
    String? category,
    GembaReportStatusFilter statusFilter = GembaReportStatusFilter.all,
  }) {
    final parts = <String>[];
    if (statusFilter != GembaReportStatusFilter.all) {
      parts.add(statusFilter.label);
    }
    final c = company?.trim();
    final b = bu?.trim();
    final s = section?.trim();
    final cat = category?.trim();
    if (c != null && c.isNotEmpty) parts.add(c);
    if (b != null && b.isNotEmpty) parts.add(b);
    if (s != null && s.isNotEmpty) parts.add(s);
    if (cat != null && cat.isNotEmpty) parts.add(cat);
    return parts.isEmpty ? 'All locations' : parts.join(' / ');
  }

  static String _buildReportHeading({
    String? company,
    String? bu,
    String? section,
    String? category,
    GembaReportStatusFilter statusFilter = GembaReportStatusFilter.all,
  }) {
    final cat = category?.trim();
    final s = section?.trim();
    final b = bu?.trim();
    final c = company?.trim();
    if (cat != null && cat.isNotEmpty) return cat;
    if (s != null && s.isNotEmpty) return s;
    if (b != null && b.isNotEmpty) return b;
    if (c != null && c.isNotEmpty) return c;
    return switch (statusFilter) {
      GembaReportStatusFilter.all => 'All observations',
      GembaReportStatusFilter.open => 'Open observations',
      GembaReportStatusFilter.closed => 'Closed observations',
    };
  }

  static String _paddedNumber(int index) => index.toString().padLeft(3, '0');

  static String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
