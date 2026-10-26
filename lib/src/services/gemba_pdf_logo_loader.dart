import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pdf/widgets.dart' as pw;

/// Rasterizes the Packages SVG logo for embedding in PDF reports.
class GembaPdfLogoLoader {
  GembaPdfLogoLoader._();

  static const asset = 'assets/images/packages-logo.svg';

  static Future<pw.MemoryImage?> load({
    double height = 64,
    int fillColor = 0xFF008FD5,
  }) async {
    try {
      final svgString = await rootBundle.loadString(asset);
      final tintedSvg = svgString.replaceAll(
        '#008FD5',
        _hexColor(fillColor),
      );
      final pictureInfo =
          await vg.loadPicture(SvgStringLoader(tintedSvg), null);
      final intrinsic = pictureInfo.size;
      if (intrinsic.height <= 0 || intrinsic.width <= 0) {
        pictureInfo.picture.dispose();
        return null;
      }

      final scale = height / intrinsic.height;
      final width = intrinsic.width * scale;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.scale(scale);
      canvas.drawPicture(pictureInfo.picture);
      pictureInfo.picture.dispose();

      final scaledPicture = recorder.endRecording();
      final image = await scaledPicture.toImage(
        width.ceil().clamp(1, 4096),
        height.ceil().clamp(1, 4096),
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return null;

      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static String _hexColor(int color) {
    final rgb = color & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
