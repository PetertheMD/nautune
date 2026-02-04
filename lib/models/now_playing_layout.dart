import 'package:flutter/material.dart';

/// Available Now Playing screen layouts
enum NowPlayingLayout {
  classic,   // Current default layout
  blur,      // Blurred album art background, floating controls
  card,      // Album art in a card with shadow, minimal background
  gradient,  // Full gradient background from album colors
  compact,   // Minimal height, more content visible
  fullArt,   // Album art fills screen, controls overlay
}

extension NowPlayingLayoutExtension on NowPlayingLayout {
  /// Display label for the layout type
  String get label {
    switch (this) {
      case NowPlayingLayout.classic:
        return 'Classic';
      case NowPlayingLayout.blur:
        return 'Blur';
      case NowPlayingLayout.card:
        return 'Card';
      case NowPlayingLayout.gradient:
        return 'Gradient';
      case NowPlayingLayout.compact:
        return 'Compact';
      case NowPlayingLayout.fullArt:
        return 'Full Art';
    }
  }

  /// Short description for the layout
  String get description {
    switch (this) {
      case NowPlayingLayout.classic:
        return 'Traditional player layout with album art and controls';
      case NowPlayingLayout.blur:
        return 'Frosted glass effect with blurred album art background';
      case NowPlayingLayout.card:
        return 'Elevated album art card with shadow';
      case NowPlayingLayout.gradient:
        return 'Dynamic gradient background from album colors';
      case NowPlayingLayout.compact:
        return 'Condensed layout with more visible content';
      case NowPlayingLayout.fullArt:
        return 'Full-screen album art with overlaid controls';
    }
  }

  /// Icon for the layout type
  IconData get icon {
    switch (this) {
      case NowPlayingLayout.classic:
        return Icons.view_agenda;
      case NowPlayingLayout.blur:
        return Icons.blur_on;
      case NowPlayingLayout.card:
        return Icons.crop_portrait;
      case NowPlayingLayout.gradient:
        return Icons.gradient;
      case NowPlayingLayout.compact:
        return Icons.view_compact;
      case NowPlayingLayout.fullArt:
        return Icons.fullscreen;
    }
  }

  /// Parse from string (for persistence)
  static NowPlayingLayout fromString(String? value) {
    switch (value) {
      case 'classic':
        return NowPlayingLayout.classic;
      case 'blur':
        return NowPlayingLayout.blur;
      case 'card':
        return NowPlayingLayout.card;
      case 'gradient':
        return NowPlayingLayout.gradient;
      case 'compact':
        return NowPlayingLayout.compact;
      case 'fullArt':
        return NowPlayingLayout.fullArt;
      default:
        return NowPlayingLayout.classic;
    }
  }
}
