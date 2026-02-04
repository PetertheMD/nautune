import 'package:flutter/material.dart';

// The flavors of eye-candy available
enum VisualizerType {
  bioluminescent,  // Ocean waves (default)
  spectrumBars,    // Classic vertical bars
  spectrumMirror,  // Mirrored bars (top/bottom)
  spectrumRadial,  // Circular/radial bars
  butterchurn,     // Milkdrop-inspired psychedelic
  globe,           // 3D particle globe
}

extension VisualizerTypeExtension on VisualizerType {
  /// Display label for the visualizer type
  String get label {
    switch (this) {
      case VisualizerType.bioluminescent:
        return 'Ocean Waves';
      case VisualizerType.spectrumBars:
        return 'Spectrum Bars';
      case VisualizerType.spectrumMirror:
        return 'Mirror Bars';
      case VisualizerType.spectrumRadial:
        return 'Radial';
      case VisualizerType.butterchurn:
        return 'Psychedelic';
      case VisualizerType.globe:
        return '3D Globe';
    }
  }

  // What it looks like
  String get description {
    switch (this) {
      case VisualizerType.bioluminescent:
        return 'Chill ocean vibes with floating lights';
      case VisualizerType.spectrumBars:
        return 'That classic 90s stereo look';
      case VisualizerType.spectrumMirror:
        return 'Rorschach test but for music';
      case VisualizerType.spectrumRadial:
        return 'Like a sun exploding to the beat';
      case VisualizerType.butterchurn:
        return 'Trippy visuals like Winamp used to have';
      case VisualizerType.globe:
        return 'A spinning planet of sound';
    }
  }

  /// Icon for the visualizer type
  IconData get icon {
    switch (this) {
      case VisualizerType.bioluminescent:
        return Icons.waves;
      case VisualizerType.spectrumBars:
        return Icons.equalizer;
      case VisualizerType.spectrumMirror:
        return Icons.align_vertical_center;
      case VisualizerType.spectrumRadial:
        return Icons.brightness_high;
      case VisualizerType.butterchurn:
        return Icons.auto_awesome;
      case VisualizerType.globe:
        return Icons.public;
    }
  }

  /// Parse from string (for persistence)
  static VisualizerType fromString(String? value) {
    switch (value) {
      case 'bioluminescent':
        return VisualizerType.bioluminescent;
      case 'spectrumBars':
        return VisualizerType.spectrumBars;
      case 'spectrumMirror':
        return VisualizerType.spectrumMirror;
      case 'spectrumRadial':
        return VisualizerType.spectrumRadial;
      case 'butterchurn':
        return VisualizerType.butterchurn;
      case 'globe':
        return VisualizerType.globe;
      default:
        return VisualizerType.bioluminescent;
    }
  }
}

/// Position where the visualizer can be displayed
enum VisualizerPosition {
  albumArt,     // Replaces album art when toggled
  controlsBar,  // Current behavior: behind playback controls
}

extension VisualizerPositionExtension on VisualizerPosition {
  /// Display label for the visualizer position
  String get label {
    switch (this) {
      case VisualizerPosition.albumArt:
        return 'Album Art';
      case VisualizerPosition.controlsBar:
        return 'Controls Bar';
    }
  }

  /// Short description for the position option
  String get description {
    switch (this) {
      case VisualizerPosition.albumArt:
        return 'Tap album art to toggle visualizer';
      case VisualizerPosition.controlsBar:
        return 'Visualizer behind playback controls';
    }
  }

  /// Icon for the visualizer position
  IconData get icon {
    switch (this) {
      case VisualizerPosition.albumArt:
        return Icons.album;
      case VisualizerPosition.controlsBar:
        return Icons.tune;
    }
  }

  /// Parse from string (for persistence)
  static VisualizerPosition fromString(String? value) {
    switch (value) {
      case 'albumArt':
        return VisualizerPosition.albumArt;
      case 'controlsBar':
        return VisualizerPosition.controlsBar;
      default:
        return VisualizerPosition.controlsBar;
    }
  }
}

// How fancy the globe should look
enum GlobeQuality {
  powerSaving,  // Fewer particles for battery efficiency
  normal,       // Default balanced quality
  high,         // More particles for visual fidelity
}

extension GlobeQualityExtension on GlobeQuality {
  /// Display label for the quality option
  String get label {
    switch (this) {
      case GlobeQuality.powerSaving:
        return 'Power Saving';
      case GlobeQuality.normal:
        return 'Normal';
      case GlobeQuality.high:
        return 'High';
    }
  }

  // What this actually means
  String get description {
    switch (this) {
      case GlobeQuality.powerSaving:
        return 'Battery saver (400 points)';
      case GlobeQuality.normal:
        return 'Balanced (800 points)';
      case GlobeQuality.high:
        return 'Show off mode (1500 points)';
    }
  }

  /// Number of particles for this quality level
  int get particleCount {
    switch (this) {
      case GlobeQuality.powerSaving:
        return 400;
      case GlobeQuality.normal:
        return 800;
      case GlobeQuality.high:
        return 1500;
    }
  }

  /// Icon for the quality option
  IconData get icon {
    switch (this) {
      case GlobeQuality.powerSaving:
        return Icons.battery_saver;
      case GlobeQuality.normal:
        return Icons.tune;
      case GlobeQuality.high:
        return Icons.auto_awesome;
    }
  }

  /// Parse from string (for persistence)
  static GlobeQuality fromString(String? value) {
    switch (value) {
      case 'powerSaving':
        return GlobeQuality.powerSaving;
      case 'normal':
        return GlobeQuality.normal;
      case 'high':
        return GlobeQuality.high;
      default:
        return GlobeQuality.normal;
    }
  }
}
