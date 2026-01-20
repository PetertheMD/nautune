import 'dart:async' show StreamSubscription;
import 'dart:io' show Platform;
import 'dart:math' show pi, sin, cos;
import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../services/pulseaudio_fft_service.dart';
import '../services/ios_fft_service.dart';

/// Bioluminescent ocean-themed audio visualizer.
/// On Linux: Uses real FFT from PulseAudio system audio loopback.
/// On other platforms: Uses metadata-driven frequency bands (genre/ReplayGain).
class BioluminescentVisualizer extends StatefulWidget {
  const BioluminescentVisualizer({
    super.key,
    required this.audioService,
    this.opacity = 0.6,
  });

  final AudioPlayerService audioService;
  final double opacity;

  @override
  State<BioluminescentVisualizer> createState() => _BioluminescentVisualizerState();
}

class _BioluminescentVisualizerState extends State<BioluminescentVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Smoothed values (interpolate towards targets each frame)
  double _smoothBass = 0.0;
  double _smoothMid = 0.0;
  double _smoothTreble = 0.0;
  double _smoothAmplitude = 0.0;

  // Target values from FFT or metadata
  double _targetBass = 0.0;
  double _targetMid = 0.0;
  double _targetTreble = 0.0;
  double _targetAmplitude = 0.0;

  // Frame rate throttling (30fps for battery savings)
  DateTime _lastFrameTime = DateTime.now();
  static const _frameInterval = Duration(milliseconds: 33); // ~30fps

  // Cached values for frame skipping (to avoid flickering)
  double _lastPaintedTime = 0;
  double _lastPaintedBass = 0;
  double _lastPaintedMid = 0;
  double _lastPaintedTreble = 0;
  double _lastPaintedAmplitude = 0;

  StreamSubscription? _playingSubscription;
  StreamSubscription? _frequencySubscription;
  StreamSubscription? _fftSubscription;

  // Real FFT sources - check synchronously from singleton services
  bool get _usePulseAudioFFT => Platform.isLinux && PulseAudioFFTService.instance.isAvailable;
  bool get _useIOSFFT => Platform.isIOS && IOSFFTService.instance.isAvailable;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _initFFTSource();

    // Listen to playing state - start/stop animation only
    // FFT capture lifecycle is managed by audio_player_service for both iOS and Linux
    _playingSubscription = widget.audioService.playingStream.listen((playing) {
      if (mounted) {
        if (playing) {
          _animationController.repeat();
        } else {
          _animationController.stop();
        }
      }
    });

    // Initial state
    if (widget.audioService.isPlaying) {
      _animationController.repeat();
    }
  }

  void _initFFTSource() {
    // Subscribe to real FFT stream if available (services are singletons, already initialized)
    if (_usePulseAudioFFT) {
      debugPrint('🌊 Visualizer: Subscribing to PulseAudio real FFT (Linux)');
      _fftSubscription = PulseAudioFFTService.instance.fftStream.listen((fft) {
        _targetBass = fft.bass;
        _targetMid = fft.mid;
        _targetTreble = fft.treble;
        _targetAmplitude = fft.amplitude;
      });
      return;
    }

    if (_useIOSFFT) {
      debugPrint('🌊 Visualizer: Subscribing to iOS real FFT');
      _fftSubscription = IOSFFTService.instance.fftStream.listen((fft) {
        _targetBass = fft.bass;
        _targetMid = fft.mid;
        _targetTreble = fft.treble;
        _targetAmplitude = fft.amplitude;
      });
      return;
    }

    // Fallback: metadata-driven frequency bands
    debugPrint('🌊 Visualizer: Using metadata-driven animation (fallback)');
    _frequencySubscription = widget.audioService.frequencyBandsStream.listen((bands) {
      _targetBass = bands.bass;
      _targetMid = bands.mid;
      _targetTreble = bands.treble;
      _targetAmplitude = ((bands.bass + bands.mid + bands.treble) / 3).clamp(0.0, 1.0);
    });
  }

  @override
  void dispose() {
    _fftSubscription?.cancel();
    _frequencySubscription?.cancel();
    _playingSubscription?.cancel();
    // FFT capture lifecycle is managed by audio_player_service (not here)
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Frame rate throttling: Only update values every ~33ms (30fps)
        final now = DateTime.now();
        final shouldUpdate = now.difference(_lastFrameTime) >= _frameInterval;

        if (shouldUpdate) {
          _lastFrameTime = now;

          // Musical smoothing: FAST attack, SLOW decay
          // When target > current: snap up quickly (attack)
          // When target < current: ease down slowly (decay)
          // Use fast smoothing for real FFT (Linux/iOS), slower for metadata fallback
          final useRealFFT = _usePulseAudioFFT || _useIOSFFT;
          final attackFactor = useRealFFT ? 0.6 : 0.3;  // Fast rise
          final decayFactor = useRealFFT ? 0.12 : 0.08;  // Slow fall

          _smoothBass += (_targetBass - _smoothBass) *
              (_targetBass > _smoothBass ? attackFactor : decayFactor);
          _smoothMid += (_targetMid - _smoothMid) *
              (_targetMid > _smoothMid ? attackFactor : decayFactor);
          _smoothTreble += (_targetTreble - _smoothTreble) *
              (_targetTreble > _smoothTreble ? attackFactor : decayFactor);
          _smoothAmplitude += (_targetAmplitude - _smoothAmplitude) *
              (_targetAmplitude > _smoothAmplitude ? attackFactor : decayFactor);

          // Cache the values for this frame
          _lastPaintedTime = _animationController.value * 10;
          _lastPaintedBass = _smoothBass;
          _lastPaintedMid = _smoothMid;
          _lastPaintedTreble = _smoothTreble;
          _lastPaintedAmplitude = _smoothAmplitude;
        }

        // Always return a valid CustomPaint with either new or cached values
        return CustomPaint(
          painter: _BioluminescentWavePainter(
            time: _lastPaintedTime,
            bass: _lastPaintedBass,
            mid: _lastPaintedMid,
            treble: _lastPaintedTreble,
            amplitude: _lastPaintedAmplitude,
            glowColor: glowColor,
            opacity: widget.opacity,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _BioluminescentWavePainter extends CustomPainter {
  final double time;
  final double bass;
  final double mid;
  final double treble;
  final double amplitude;
  final Color glowColor;
  final double opacity;

  // Cached paint objects to avoid allocation in paint()
  late final Paint _wavePaint0;
  late final Paint _wavePaint1;
  late final Paint _wavePaint2;
  late final Paint _pulsePaint;
  late final Paint _particlePaint;
  late final Paint _gradientPaint;
  late final Paint _topGlowPaint;

  // Cached mask filters (immutable, safe to reuse)
  static const MaskFilter _blurFilter12 = MaskFilter.blur(BlurStyle.normal, 12);
  static const MaskFilter _blurFilter6 = MaskFilter.blur(BlurStyle.normal, 6);
  static const MaskFilter _blurFilter3 = MaskFilter.blur(BlurStyle.normal, 3);
  static const MaskFilter _blurFilter15 = MaskFilter.blur(BlurStyle.normal, 15);
  static const MaskFilter _blurFilter10 = MaskFilter.blur(BlurStyle.normal, 10);

  // Pre-computed colors (computed once in constructor)
  late final Color _waveColor0;
  late final Color _waveColor1;
  late final Color _waveColor2;

  _BioluminescentWavePainter({
    required this.time,
    required this.bass,
    required this.mid,
    required this.treble,
    required this.amplitude,
    required this.glowColor,
    required this.opacity,
  }) {
    // Pre-compute wave colors for each layer
    _waveColor0 = glowColor.withValues(alpha: opacity * 0.8);
    _waveColor1 = glowColor.withValues(alpha: opacity * 0.85 * 0.8);
    _waveColor2 = glowColor.withValues(alpha: opacity * 0.7 * 0.8);

    // Initialize cached paint objects
    _wavePaint0 = Paint()
      ..color = _waveColor0
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = _blurFilter12;

    _wavePaint1 = Paint()
      ..color = _waveColor1
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..maskFilter = _blurFilter6;

    _wavePaint2 = Paint()
      ..color = _waveColor2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..maskFilter = _blurFilter3;

    _pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = _blurFilter15;

    _particlePaint = Paint()
      ..maskFilter = _blurFilter10;

    _gradientPaint = Paint();
    _topGlowPaint = Paint();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // DRAMATIC bass response - wave height scales massively with bass
    final baseAmplitude = 0.08 + amplitude * 0.25;
    final bassAmplitude = baseAmplitude + bass * 2.0;  // HUGE bass impact

    // Pre-compute shared values
    final halfHeight = size.height / 2;
    final halfWidth = size.width / 2;

    // Draw wave layers using cached paints
    final wavePaints = [_wavePaint0, _wavePaint1, _wavePaint2];

    for (int layer = 0; layer < 3; layer++) {
      final paint = wavePaints[layer];

      final path = Path();
      final waveAmplitude = size.height * bassAmplitude * (1 - layer * 0.15);
      final phase = time + layer * 0.5;
      final frequency = 2.5 + layer * 0.3 + bass * 0.5;

      path.moveTo(0, halfHeight);
      for (double x = 0; x <= size.width; x += 2) {
        final normalizedX = x / size.width;

        // Primary wave
        final y1 = sin(normalizedX * frequency * pi + phase) * waveAmplitude;

        // Secondary harmonic
        final y2 = sin(normalizedX * frequency * 2.5 * pi + phase * 1.3) *
                   waveAmplitude * 0.35 * (0.2 + mid * 2.0);

        // Sub-bass rumble
        final subBass = sin(normalizedX * 1.5 * pi + time * 0.7) *
                        bass * size.height * 0.15;

        // Treble shimmer
        final shimmer = sin(normalizedX * 20 * pi + time * 4) *
                        treble * size.height * 0.08;

        path.lineTo(x, halfHeight + y1 + y2 + subBass + shimmer);
      }
      canvas.drawPath(path, paint);
    }

    // BASS PULSE - expanding rings on bass hits
    if (bass > 0.3) {
      final pulseRadius = size.width * 0.3 * bass;
      _pulsePaint.color = glowColor.withValues(alpha: opacity * bass * 0.5);
      canvas.drawCircle(Offset(halfWidth, halfHeight), pulseRadius, _pulsePaint);
    }

    // Floating bioluminescent particles
    for (int i = 0; i < 15; i++) {
      final particlePhase = i * 0.42;
      final speed = 0.06 + mid * 0.2 + bass * 0.1;

      final px = ((time * speed + particlePhase) % 1.0) * size.width;
      final verticalPhase = time * 0.4 + i * 0.7;

      final py = halfHeight +
          sin(verticalPhase) * size.height * 0.4 * bassAmplitude +
          cos(verticalPhase * 2) * bass * size.height * 0.15;

      final radius = 3.0 + bass * 12.0 + treble * 5.0 + amplitude * 4.0 +
                     sin(time * 3 + i) * 2.0;
      final particleOpacity = (0.5 + sin(time * 2 + i * 0.5) * 0.3 + bass * 0.3) * opacity;

      _particlePaint.color = glowColor.withValues(alpha: particleOpacity.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(px, py), radius.clamp(2.0, 20.0), _particlePaint);
    }

    // Bottom gradient glow
    final glowIntensity = 0.2 + bass * 0.6 + amplitude * 0.3;
    final bottomRect = Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.6);
    _gradientPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        glowColor.withValues(alpha: opacity * glowIntensity.clamp(0.0, 0.8)),
      ],
    ).createShader(bottomRect);
    canvas.drawRect(bottomRect, _gradientPaint);

    // Top edge glow on big bass hits
    if (bass > 0.5) {
      final topRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.3);
      _topGlowPaint.shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.transparent,
          glowColor.withValues(alpha: opacity * (bass - 0.5) * 0.8),
        ],
      ).createShader(topRect);
      canvas.drawRect(topRect, _topGlowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BioluminescentWavePainter old) {
    // Only repaint if values have changed significantly
    // Use threshold comparison to avoid unnecessary repaints for tiny changes
    const threshold = 0.01;
    return (old.bass - bass).abs() > threshold ||
           (old.mid - mid).abs() > threshold ||
           (old.treble - treble).abs() > threshold ||
           (old.amplitude - amplitude).abs() > threshold ||
           (old.time - time).abs() > 0.016 || // ~60fps time threshold
           old.glowColor != glowColor ||
           old.opacity != opacity;
  }
}
