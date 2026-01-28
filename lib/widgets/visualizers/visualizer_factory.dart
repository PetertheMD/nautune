import 'package:flutter/material.dart';
import '../../models/visualizer_type.dart';
import '../../services/audio_player_service.dart';
import 'bioluminescent_visualizer.dart';
import 'spectrum_bars_visualizer.dart';
import 'spectrum_mirror_visualizer.dart';
import 'spectrum_radial_visualizer.dart';
import 'butterchurn_visualizer.dart';

/// Factory widget that returns the appropriate visualizer based on type.
class VisualizerFactory extends StatelessWidget {
  const VisualizerFactory({
    super.key,
    required this.type,
    required this.audioService,
    this.opacity = 0.6,
  });

  final VisualizerType type;
  final AudioPlayerService audioService;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case VisualizerType.bioluminescent:
        return BioluminescentVisualizer(
          key: const ValueKey('bioluminescent'),
          audioService: audioService,
          opacity: opacity,
        );

      case VisualizerType.spectrumBars:
        return SpectrumBarsVisualizer(
          key: const ValueKey('spectrumBars'),
          audioService: audioService,
          opacity: opacity,
        );

      case VisualizerType.spectrumMirror:
        return SpectrumMirrorVisualizer(
          key: const ValueKey('spectrumMirror'),
          audioService: audioService,
          opacity: opacity,
        );

      case VisualizerType.spectrumRadial:
        return SpectrumRadialVisualizer(
          key: const ValueKey('spectrumRadial'),
          audioService: audioService,
          opacity: opacity,
        );

      case VisualizerType.butterchurn:
        return ButterchurnVisualizer(
          key: const ValueKey('butterchurn'),
          audioService: audioService,
          opacity: opacity,
        );
    }
  }
}
