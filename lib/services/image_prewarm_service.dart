import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import '../jellyfin/jellyfin_service.dart';
import '../jellyfin/jellyfin_track.dart';
import '../jellyfin/jellyfin_album.dart';

/// Service for pre-warming (pre-caching) images to improve perceived performance
class ImagePrewarmService {
  final JellyfinService _jellyfinService;
  final Set<String> _prewarmingUrls = {};
  final Set<String> _prewarmedUrls = {};

  ImagePrewarmService({required JellyfinService jellyfinService})
      : _jellyfinService = jellyfinService;

  /// Pre-warm album art for a list of tracks (non-blocking)
  void prewarmTrackImages(List<JellyfinTrack> tracks) {
    for (final track in tracks) {
      _prewarmTrackImage(track);
    }
  }

  /// Pre-warm album art for a list of albums (non-blocking)
  void prewarmAlbumImages(List<JellyfinAlbum> albums) {
    for (final album in albums) {
      _prewarmAlbumImage(album);
    }
  }

  /// Pre-warm a single track's album art
  void _prewarmTrackImage(JellyfinTrack track) {
    String? imageTag = track.primaryImageTag ?? track.albumPrimaryImageTag ?? track.parentThumbImageTag;
    String? itemId = imageTag != null ? (track.albumId ?? track.id) : null;

    if (itemId == null || imageTag == null) return;

    _prewarmImage(itemId, imageTag);
  }

  /// Pre-warm a single album's art
  void _prewarmAlbumImage(JellyfinAlbum album) {
    final imageTag = album.primaryImageTag;
    if (imageTag == null) return;

    _prewarmImage(album.id, imageTag);
  }

  /// Pre-warm a single image by URL
  void _prewarmImage(String itemId, String imageTag) {
    final imageUrl = _jellyfinService.buildImageUrl(
      itemId: itemId,
      tag: imageTag,
      maxWidth: 400,
    );

    // Skip if already prewarming or prewarmed
    if (_prewarmingUrls.contains(imageUrl) || _prewarmedUrls.contains(imageUrl)) {
      return;
    }

    _prewarmingUrls.add(imageUrl);

    try {
      final provider = CachedNetworkImageProvider(
        imageUrl,
        headers: _jellyfinService.imageHeaders(),
      );

      // Use resolve to trigger the image load into cache
      final stream = provider.resolve(const ImageConfiguration());

      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, synchronousCall) {
          _prewarmedUrls.add(imageUrl);
          _prewarmingUrls.remove(imageUrl);
          stream.removeListener(listener);
        },
        onError: (exception, stackTrace) {
          _prewarmingUrls.remove(imageUrl);
          stream.removeListener(listener);
          debugPrint('ImagePrewarm: Failed to prewarm: $exception');
        },
      );

      stream.addListener(listener);

      // Auto-cleanup after timeout
      Future.delayed(const Duration(seconds: 15), () {
        if (_prewarmingUrls.contains(imageUrl)) {
          _prewarmingUrls.remove(imageUrl);
          stream.removeListener(listener);
        }
      });
    } catch (e) {
      _prewarmingUrls.remove(imageUrl);
      debugPrint('ImagePrewarm: Error prewarming image: $e');
    }
  }

  /// Pre-warm images for the next N tracks in the queue
  void prewarmQueueImages(List<JellyfinTrack> queue, int currentIndex, {int count = 3}) {
    final startIndex = currentIndex + 1;
    final endIndex = (startIndex + count).clamp(0, queue.length);

    if (startIndex >= queue.length) return;

    final tracksToPrewarm = queue.sublist(startIndex, endIndex);
    prewarmTrackImages(tracksToPrewarm);

    debugPrint('ImagePrewarm: Prewarming ${tracksToPrewarm.length} upcoming queue images');
  }

  /// Clear the prewarmed cache tracking (doesn't clear actual image cache)
  void clearTracking() {
    _prewarmingUrls.clear();
    _prewarmedUrls.clear();
  }

  /// Get stats about prewarming
  Map<String, int> get stats => {
    'prewarming': _prewarmingUrls.length,
    'prewarmed': _prewarmedUrls.length,
  };
}
