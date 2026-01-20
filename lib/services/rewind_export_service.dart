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

/// Service for exporting Rewind cards as images for sharing
class RewindExportService {
  static RewindExportService? _instance;
  static RewindExportService get instance => _instance ??= RewindExportService._();

  RewindExportService._();

  static const _methodChannel = MethodChannel('com.nautune.share/methods');

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

  /// Save image bytes to a temporary file
  Future<File?> saveToTempFile(Uint8List imageBytes, String filename) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename.png');
      await file.writeAsBytes(imageBytes);
      debugPrint('RewindExportService: Saved to ${file.path}');
      return file;
    } catch (e) {
      debugPrint('RewindExportService: Error saving file: $e');
      return null;
    }
  }

  /// Share an image file using platform share sheet
  Future<ExportResult> shareImage(File imageFile, {String? title}) async {
    if (Platform.isIOS) {
      return _shareIOS(imageFile, title: title);
    } else if (Platform.isLinux) {
      return _shareLinux(imageFile);
    } else if (Platform.isMacOS) {
      return _shareMacOS(imageFile);
    } else if (Platform.isAndroid) {
      return _shareAndroid(imageFile, title: title);
    }

    debugPrint('RewindExportService: Platform not supported');
    return ExportResult.error;
  }

  /// iOS sharing via UIActivityViewController
  Future<ExportResult> _shareIOS(File imageFile, {String? title}) async {
    try {
      final result = await _methodChannel.invokeMethod<dynamic>('shareImage', {
        'imagePath': imageFile.path,
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
  Future<ExportResult> _shareLinux(File imageFile) async {
    try {
      // Try nautilus with --select to highlight the file
      try {
        final nautilusResult = await Process.run('nautilus', ['--select', imageFile.path]);
        if (nautilusResult.exitCode == 0) {
          debugPrint('RewindExportService: Opened nautilus with file selected');
          return ExportResult.success;
        }
      } catch (_) {
        // nautilus not available
      }

      // Try dolphin (KDE)
      try {
        final dolphinResult = await Process.run('dolphin', ['--select', imageFile.path]);
        if (dolphinResult.exitCode == 0) {
          debugPrint('RewindExportService: Opened dolphin with file selected');
          return ExportResult.success;
        }
      } catch (_) {
        // dolphin not available
      }

      // Fallback: open the directory
      final directory = imageFile.parent.path;
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
  Future<ExportResult> _shareMacOS(File imageFile) async {
    try {
      final result = await Process.run('open', ['-R', imageFile.path]);
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
  Future<ExportResult> _shareAndroid(File imageFile, {String? title}) async {
    try {
      final result = await _methodChannel.invokeMethod<dynamic>('shareImage', {
        'imagePath': imageFile.path,
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

  /// Capture and share a Rewind card
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

    // Save to temp file
    final yearStr = year?.toString() ?? 'all-time';
    final cardStr = cardName ?? 'rewind';
    final filename = 'nautune_rewind_${yearStr}_$cardStr';
    final file = await saveToTempFile(imageBytes, filename);
    if (file == null) {
      return ExportResult.error;
    }

    // Share
    return shareImage(file, title: 'My $yearStr Nautune Rewind');
  }
}
