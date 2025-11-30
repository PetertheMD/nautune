import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class JellyfinImage extends StatelessWidget {
  const JellyfinImage({
    super.key,
    required this.itemId,
    required this.imageTag,
    this.width,
    this.height,
    this.maxWidth,
    this.maxHeight,
    this.boxFit = BoxFit.cover,
    this.errorBuilder,
    this.placeholderBuilder,
  });

  final String itemId;
  final String? imageTag;
  final double? width;
  final double? height;
  final int? maxWidth;
  final int? maxHeight;
  final BoxFit boxFit;
  final Widget Function(BuildContext context, String url, dynamic error)? errorBuilder;
  final Widget Function(BuildContext context, String url)? placeholderBuilder;

  @override
  Widget build(BuildContext context) {
    if (imageTag == null || imageTag!.isEmpty) {
      return _buildError(context, 'No image tag provided');
    }

    final appState = Provider.of<NautuneAppState>(context, listen: false);
    
    // Determine optimal dimensions for request
    final requestWidth = maxWidth ?? (width != null ? (width! * 2).toInt() : 400);
    final requestHeight = maxHeight ?? (height != null ? (height! * 2).toInt() : null);

    final imageUrl = appState.jellyfinService.buildImageUrl(
      itemId: itemId,
      tag: imageTag!,
      maxWidth: requestWidth,
      maxHeight: requestHeight,
    );

    return CachedNetworkImage(
      imageUrl: imageUrl,
      httpHeaders: appState.jellyfinService.imageHeaders(),
      width: width,
      height: height,
      fit: boxFit,
      placeholder: placeholderBuilder != null 
          ? (context, url) => placeholderBuilder!(context, url)
          : (context, url) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                width: width,
                height: height,
              ),
      errorWidget: errorBuilder != null
          ? (context, url, error) => errorBuilder!(context, url, error)
          : (context, url, error) => _buildError(context, error),
      memCacheWidth: requestWidth,
      // Disk cache is handled automatically by cached_network_image
    );
  }

  Widget _buildError(BuildContext context, dynamic error) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      width: width,
      height: height,
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
