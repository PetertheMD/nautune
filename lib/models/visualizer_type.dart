import 'package:flutter/material.dart';

/// Available visualizer styles for audio visualization
enum VisualizerType {
  bioluminescent,  // Ocean waves (default)
  spectrumBars,    // Classic vertical bars
  spectrumMirror,  // Mirrored bars (top/bottom)
  spectrumRadial,  // Circular/radial bars
  butterchurn,     // Milkdrop-inspired psychedelic
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
    }
  }

  /// Short description for the visualizer
  String get description {
    switch (this) {
      case VisualizerType.bioluminescent:
        return 'Bioluminescent ocean waves with floating particles';
      case VisualizerType.spectrumBars:
        return 'Classic vertical frequency bars with peak hold';
      case VisualizerType.spectrumMirror:
        return 'Symmetric bars extending from center';
      case VisualizerType.spectrumRadial:
        return 'Circular bars with slow rotation';
      case VisualizerType.butterchurn:
        return 'Milkdrop-style psychedelic effects';
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
      default:
        return VisualizerType.bioluminescent;
    }
  }
}
