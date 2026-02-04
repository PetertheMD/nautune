import 'package:flutter/material.dart';
import '../../models/visualizer_type.dart';
import '../../services/audio_player_service.dart';
import 'bioluminescent_visualizer.dart';
import 'spectrum_bars_visualizer.dart';
import 'spectrum_mirror_visualizer.dart';
import 'spectrum_radial_visualizer.dart';
import 'butterchurn_visualizer.dart';
import 'globe_visualizer.dart';

// Selects the right visualizer widget based on your mood (or settings)
class VisualizerFactory extends StatelessWidget {
  const VisualizerFactory({
    super.key,
    required this.type,
    required this.audioService,
    this.opacity = 0.6,
    this.globeQuality = GlobeQuality.normal,
    this.isVisible = true,
  });

  final VisualizerType type;
  final AudioPlayerService audioService;
  final double opacity;
  final GlobeQuality globeQuality;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case VisualizerType.bioluminescent:
        return BioluminescentVisualizer(
          key: const ValueKey('bioluminescent'),
          audioService: audioService,
          opacity: opacity,
          isVisible: isVisible,
        );

      case VisualizerType.spectrumBars:
        return SpectrumBarsVisualizer(
          key: const ValueKey('spectrumBars'),
          audioService: audioService,
          opacity: opacity,
          isVisible: isVisible,
        );

      case VisualizerType.spectrumMirror:
        return SpectrumMirrorVisualizer(
          key: const ValueKey('spectrumMirror'),
          audioService: audioService,
          opacity: opacity,
          isVisible: isVisible,
        );

      case VisualizerType.spectrumRadial:
        return SpectrumRadialVisualizer(
          key: const ValueKey('spectrumRadial'),
          audioService: audioService,
          opacity: opacity,
          isVisible: isVisible,
        );

      case VisualizerType.butterchurn:
        return ButterchurnVisualizer(
          key: const ValueKey('butterchurn'),
          audioService: audioService,
          opacity: opacity,
          isVisible: isVisible,
        );

      case VisualizerType.globe:
        return GlobeVisualizer(
          key: ValueKey('globe_${globeQuality.name}'),
          audioService: audioService,
          opacity: opacity,
          quality: globeQuality,
          isVisible: isVisible,
        );
    }
  }
}
