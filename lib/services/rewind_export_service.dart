import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Result of an export operation
enum ExportResult {
  success,
  cancelled,
  error,
}

/// Service for exporting Rewind cards as images/PDF for sharing
class RewindExportService {
  static RewindExportService? _instance;
  static RewindExportService get instance => _instance ??= RewindExportService._();

  RewindExportService._();

  static const _methodChannel = MethodChannel('com.nautune.share/methods');

  /// Get the Nautune documents folder path
  Future<Directory> _getNautuneDocsFolder() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final Directory nautuneDir;

    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      nautuneDir = Directory('${docsDir.path}${Platform.pathSeparator}nautune${Platform.pathSeparator}rewind');
    } else {
      // iOS/Android: Use app documents directory
      nautuneDir = Directory('${docsDir.path}/rewind');
    }

    if (!await nautuneDir.exists()) {
      await nautuneDir.create(recursive: true);
    }

    return nautuneDir;
  }

  /// Capture a widget as an image using RepaintBoundary
  Future<Uint8List?> captureWidget(GlobalKey repaintBoundaryKey, {double pixelRatio = 3.0}) async {
    try {
      final boundary = repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('RewindExportService: RenderRepaintBoundary not found');
        return null;
      }

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint('RewindExportService: Failed to convert image to bytes');
        return null;
      }

      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('RewindExportService: Error capturing widget: $e');
      return null;
    }
  }

  /// Save image bytes to the Nautune documents folder
  Future<File?> saveToDocsFolder(Uint8List imageBytes, String filename) async {
    try {
      final nautuneDir = await _getNautuneDocsFolder();
      final file = File('${nautuneDir.path}${Platform.pathSeparator}$filename.png');
      await file.writeAsBytes(imageBytes);
      debugPrint('RewindExportService: Saved to ${file.path}');
      return file;
    } catch (e) {
      debugPrint('RewindExportService: Error saving file: $e');
      return null;
    }
  }

  /// Export all Rewind pages as a combined PNG (stitched vertically)
  /// Takes a list of image bytes (one per page)
  Future<File?> exportAllPagesAsCombinedPng({
    required List<Uint8List> pageImages,
    required int? year,
  }) async {
    if (pageImages.isEmpty) {
      debugPrint('RewindExportService: No pages to export');
      return null;
    }

    try {
      // Decode all images to get dimensions
      final List<ui.Image> decodedImages = [];
      for (final bytes in pageImages) {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        decodedImages.add(frame.image);
      }

      if (decodedImages.isEmpty) {
        debugPrint('RewindExportService: Failed to decode images');
        return null;
      }

      // Calculate combined dimensions (all same width, stack vertically)
      final width = decodedImages.first.width;
      int totalHeight = 0;
      for (final img in decodedImages) {
        totalHeight += img.height;
      }

      // Create a picture recorder to draw combined image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), totalHeight.toDouble()));

      // Draw each image vertically stacked
      double yOffset = 0;
      for (final img in decodedImages) {
        canvas.drawImage(img, Offset(0, yOffset), Paint());
        yOffset += img.height;
      }

      // Convert to image
      final picture = recorder.endRecording();
      final combinedImage = await picture.toImage(width, totalHeight);
      final byteData = await combinedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint('RewindExportService: Failed to encode combined image');
        return null;
      }

      // Save to file
      final nautuneDir = await _getNautuneDocsFolder();
      final yearStr = year?.toString() ?? 'all-time';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'nautune_rewind_${yearStr}_$timestamp.png';
      final filePath = '${nautuneDir.path}${Platform.pathSeparator}$filename';

      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      debugPrint('RewindExportService: Exported combined PNG with ${pageImages.length} pages to ${file.path}');
      return file;
    } catch (e) {
      debugPrint('RewindExportService: Error creating combined PNG: $e');
      return null;
    }
  }

  /// Share a file using platform share sheet
  Future<ExportResult> shareFile(File file, {String? title}) async {
    if (Platform.isIOS) {
      return _shareIOS(file, title: title);
    } else if (Platform.isLinux) {
      return _shareLinux(file);
    } else if (Platform.isMacOS) {
      return _shareMacOS(file);
    } else if (Platform.isAndroid) {
      return _shareAndroid(file, title: title);
    }

    debugPrint('RewindExportService: Platform not supported');
    return ExportResult.error;
  }

  /// iOS sharing via UIActivityViewController
  Future<ExportResult> _shareIOS(File file, {String? title}) async {
    try {
      final result = await _methodChannel.invokeMethod<dynamic>('shareFile', {
        'filePath': file.path,
        'title': title ?? 'My Nautune Rewind',
      });

      if (result == true) {
        debugPrint('RewindExportService: iOS share completed');
        return ExportResult.success;
      } else if (result == false) {
        debugPrint('RewindExportService: iOS share cancelled');
        return ExportResult.cancelled;
      }
      return ExportResult.error;
    } on PlatformException catch (e) {
      debugPrint('RewindExportService iOS error: ${e.code} - ${e.message}');
      return ExportResult.error;
    } catch (e) {
      debugPrint('RewindExportService iOS error: $e');
      return ExportResult.error;
    }
  }

  /// Linux sharing - opens file manager with file selected
  Future<ExportResult> _shareLinux(File file) async {
    try {
      // Try nautilus with --select to highlight the file
      try {
        final nautilusResult = await Process.run('nautilus', ['--select', file.path]);
        if (nautilusResult.exitCode == 0) {
          debugPrint('RewindExportService: Opened nautilus with file selected');
          return ExportResult.success;
        }
      } catch (_) {
        // nautilus not available
      }

      // Try dolphin (KDE)
      try {
        final dolphinResult = await Process.run('dolphin', ['--select', file.path]);
        if (dolphinResult.exitCode == 0) {
          debugPrint('RewindExportService: Opened dolphin with file selected');
          return ExportResult.success;
        }
      } catch (_) {
        // dolphin not available
      }

      // Fallback: open the directory
      final directory = file.parent.path;
      final xdgResult = await Process.run('xdg-open', [directory]);
      if (xdgResult.exitCode == 0) {
        debugPrint('RewindExportService: Opened directory with xdg-open');
        return ExportResult.success;
      }

      return ExportResult.error;
    } catch (e) {
      debugPrint('RewindExportService Linux error: $e');
      return ExportResult.error;
    }
  }

  /// macOS sharing - reveal file in Finder
  Future<ExportResult> _shareMacOS(File file) async {
    try {
      final result = await Process.run('open', ['-R', file.path]);
      if (result.exitCode == 0) {
        debugPrint('RewindExportService: Revealed file in Finder');
        return ExportResult.success;
      }
      return ExportResult.error;
    } catch (e) {
      debugPrint('RewindExportService macOS error: $e');
      return ExportResult.error;
    }
  }

  /// Android sharing via Intent
  Future<ExportResult> _shareAndroid(File file, {String? title}) async {
    try {
      final result = await _methodChannel.invokeMethod<dynamic>('shareFile', {
        'filePath': file.path,
        'title': title ?? 'My Nautune Rewind',
      });

      if (result == true) {
        return ExportResult.success;
      } else if (result == false) {
        return ExportResult.cancelled;
      }
      return ExportResult.error;
    } on PlatformException catch (e) {
      debugPrint('RewindExportService Android error: ${e.code} - ${e.message}');
      return ExportResult.error;
    } catch (e) {
      debugPrint('RewindExportService Android error: $e');
      return ExportResult.error;
    }
  }

  /// Capture all pages and export as combined PNG
  /// Takes a list of GlobalKeys for each page's RepaintBoundary
  Future<ExportResult> captureAllAndExportPng({
    required List<GlobalKey> pageKeys,
    required int? year,
  }) async {
    final List<Uint8List> pageImages = [];

    for (int i = 0; i < pageKeys.length; i++) {
      final imageBytes = await captureWidget(pageKeys[i], pixelRatio: 3.0);
      if (imageBytes != null) {
        pageImages.add(imageBytes);
        debugPrint('RewindExportService: Captured page ${i + 1}/${pageKeys.length}');
      } else {
        debugPrint('RewindExportService: Failed to capture page ${i + 1}');
      }
    }

    if (pageImages.isEmpty) {
      debugPrint('RewindExportService: No pages captured');
      return ExportResult.error;
    }

    final pngFile = await exportAllPagesAsCombinedPng(
      pageImages: pageImages,
      year: year,
    );

    if (pngFile == null) {
      return ExportResult.error;
    }

    final yearStr = year?.toString() ?? 'All Time';
    return shareFile(pngFile, title: 'My $yearStr Nautune Rewind');
  }

  /// Legacy: Capture and share a single Rewind card (kept for backwards compatibility)
  Future<ExportResult> captureAndShare(
    GlobalKey repaintBoundaryKey, {
    required int? year,
    String? cardName,
  }) async {
    // Capture the widget
    final imageBytes = await captureWidget(repaintBoundaryKey, pixelRatio: 3.0);
    if (imageBytes == null) {
      return ExportResult.error;
    }

    // Save to Nautune docs folder
    final yearStr = year?.toString() ?? 'all-time';
    final cardStr = cardName ?? 'rewind';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'nautune_rewind_${yearStr}_${cardStr}_$timestamp';
    final file = await saveToDocsFolder(imageBytes, filename);
    if (file == null) {
      return ExportResult.error;
    }

    // Share
    return shareFile(file, title: 'My $yearStr Nautune Rewind');
  }
}
