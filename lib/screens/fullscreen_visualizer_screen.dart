import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../jellyfin/jellyfin_track.dart';
import '../services/audio_player_service.dart';
import '../widgets/jellyfin_waveform.dart';

class FullscreenVisualizerScreen extends StatefulWidget {
  const FullscreenVisualizerScreen({
    super.key,
    required this.track,
    required this.audioService,
  });

  final JellyfinTrack track;
  final AudioPlayerService audioService;

  @override
  State<FullscreenVisualizerScreen> createState() =>
      _FullscreenVisualizerScreenState();
}

class _FullscreenVisualizerScreenState extends State<FullscreenVisualizerScreen> {
  bool _wasFullScreen = false;

  @override
  void initState() {
    super.initState();
    _enterFullScreen();
  }

  @override
  void dispose() {
    _exitFullScreen();
    super.dispose();
  }

  Future<void> _enterFullScreen() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      _wasFullScreen = await windowManager.isFullScreen();
      if (!_wasFullScreen) {
        await windowManager.setFullScreen(true);
      }
    }
  }

  Future<void> _exitFullScreen() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      if (!_wasFullScreen) {
        await windowManager.setFullScreen(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background Gradient (subtle animation could be added later)
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.2),
                    Colors.black,
                  ],
                ),
              ),
            ),

            // 2. Centered Visualizer (Mirrored Waveform)
            Center(
              child: StreamBuilder<Duration>(
                stream: widget.audioService.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final duration = widget.track.duration ?? Duration.zero;
                  final progress = duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0;

                  return SizedBox(
                    height: 400,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        // Top half (original)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 200,
                          child: JellyfinWaveform(
                            track: widget.track,
                            progress: progress,
                            width: MediaQuery.of(context).size.width,
                            height: 200,
                          ),
                        ),
                        // Bottom half (mirrored reflection)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 200,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.rotationX(3.14159), // Flip vertically
                            child: Opacity(
                              opacity: 0.5,
                              child: JellyfinWaveform(
                                track: widget.track,
                                progress: progress,
                                width: MediaQuery.of(context).size.width,
                                height: 200,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 3. Track Info Overlay (Minimal)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  children: [
                    Text(
                      widget.track.name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.track.displayArtist,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            // 4. Close hint
            const Positioned(
              top: 40,
              right: 40,
              child: Icon(
                Icons.fullscreen_exit,
                color: Colors.white30,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
