import 'dart:math' show cos, max, min, pi, sin, sqrt;
import 'package:flutter/material.dart';
import 'base_visualizer.dart';
import '../../models/visualizer_type.dart';

/// 3D Globe Visualizer based on Fibonacci Sphere points.
///
/// Features:
/// - Adjustable particle count based on quality setting
/// - Reaction to bass/audio amplitude
/// - Smooth rotation and zoom
/// - Optimized for mobile performance
class GlobeVisualizer extends BaseVisualizer {
  const GlobeVisualizer({
    super.key,
    required super.audioService,
    super.opacity = 0.6,
    this.quality = GlobeQuality.normal,
  });

  /// Graphics quality level (affects particle count)
  final GlobeQuality quality;

  @override
  State<GlobeVisualizer> createState() => _GlobeVisualizerState();
}

class _GlobeVisualizerState extends BaseVisualizerState<GlobeVisualizer> {
  // Points array - regenerated when quality changes
  List<_GlobePoint> _points = [];
  int _currentPointCount = 0;

  @override
  void initState() {
    super.initState();
    _regeneratePoints();
  }

  @override
  void didUpdateWidget(GlobeVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quality != widget.quality) {
      _regeneratePoints();
    }
  }

  void _regeneratePoints() {
    _currentPointCount = widget.quality.particleCount;
    _points = List.filled(_currentPointCount, const _GlobePoint(0, 0, 0, 0));
    _generateFibonacciSphere();
  }

  // Create an evenly distributed sphere of points
  // Also, unlike the flat earth theories, this one is definitely round
  void _generateFibonacciSphere() {
    final goldenAngle = pi * (3.0 - sqrt(5.0));

    for (int i = 0; i < _currentPointCount; i++) {
      // Calculate point position
      final t = i / (_currentPointCount - 1);
      final yy = 1.0 - 2.0 * t;
      final r = sqrt(max(0.0, 1.0 - yy * yy));
      final theta = goldenAngle * i;

      // Convert to Cartesian
      final x = cos(theta) * r;
      final z = sin(theta) * r;

      // Map height to frequency band
      final bandIndex = ((yy + 1.0) / 2.0) * 63.0;

      _points[i] = _GlobePoint(x, yy, z, bandIndex);
    }
  }

  @override
  Widget buildVisualizer(BuildContext context) {
    // Get spectrum data and theme color
    final spectrum = getSpectrumBars(64);
    final safeSpectrum = spectrum.isEmpty 
        ? List.filled(64, 0.0) 
        : spectrum;
    final color = Theme.of(context).colorScheme.primary;

    return CustomPaint(
      painter: _GlobePainter(
        points: _points,
        spectrum: safeSpectrum,
        time: lastPaintedTime, // from BaseVisualizer
        bass: smoothBass, // from BaseVisualizer
        amplitude: smoothAmplitude, // from BaseVisualizer
        color: color,
        opacity: widget.opacity,
      ),
      size: Size.infinite,
    );
  }
}

/// Simple immutable container for point data
class _GlobePoint {
  final double x;
  final double y;
  final double z;
  final double bandIndex;

  const _GlobePoint(this.x, this.y, this.z, this.bandIndex);
}

class _GlobePainter extends CustomPainter {
  final List<_GlobePoint> points;
  final List<double> spectrum;
  final double time;
  final double bass;
  final double amplitude;
  final Color color;
  final double opacity;

  // Cache rotation trigonometry
  late final double _sinY;
  late final double _cosY;
  late final double _sinX;
  late final double _cosX;

  _GlobePainter({
    required this.points,
    required this.spectrum,
    required this.time,
    required this.bass,
    required this.amplitude,
    required this.color,
    required this.opacity,
  }) {
    // Set up rotation based on time
    final rotY = time * 0.15; 
    final rotX = sin(time * 0.13) * 0.18;

    _sinY = sin(rotY);
    _cosY = cos(rotY);
    _sinX = sin(rotX);
    _cosX = cos(rotX);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    
    // Scale globe based on screen size
    final radius = min(size.width, size.height) * 0.35; // slightly larger than HTML's 0.28
    
    // Field of view for perspective
    final fov = radius * 2.2;
    
    // Gain/Volume boost (keep base gain)
    final audioGain = 1.0 + amplitude * 0.5;

    // Prepare points for projection
    final List<_ProjectedPoint> projectedPoints = List.filled(
      points.length, 
      const _ProjectedPoint(0, 0, 0, 0, 0),
    );

    // Project, rotate, and apply audio boost to each point
    for (int i = 0; i < points.length; i++) {
        final p = points[i];
        
        // Calculate amplitude with rough interpolation
        final binFloat = p.bandIndex;
        final binLow = binFloat.floor();
        final binHigh = min(binLow + 1, spectrum.length - 1);
        final blend = binFloat - binLow;
        
        final safeBinLow = binLow.clamp(0, spectrum.length - 1);
        final safeBinHigh = binHigh.clamp(0, spectrum.length - 1);
        
        final ampLow = spectrum[safeBinLow];
        final ampHigh = spectrum[safeBinHigh];
        
        // Apply boosts to mids and treble
        double freqBoost = 1.0;
        if (binFloat > 15 && binFloat < 45) {
          // Mid boost (subtle)
          freqBoost = 1.4;
        } else if (binFloat >= 45) {
          freqBoost = 1.8;
        }

        final amp = (ampLow * (1.0 - blend) + ampHigh * blend) * audioGain * freqBoost;
        
        // Rotate point in 3D space
        final y1 = p.y * _cosX - p.z * _sinX;
        final z1 = p.y * _sinX + p.z * _cosX;
        
        final rx = p.x * _cosY + z1 * _sinY;
        final ry = y1;
        final rz = -p.x * _sinY + z1 * _cosY;
        
        // Push point outward based on volume
        final push = 1.0 + amp * 0.22;
        final px = rx * push;
        final py = ry * push;
        final pz = rz * push;
        
        projectedPoints[i] = _ProjectedPoint(i, px, py, pz, amp);
    }
    
    // Sort so we draw back-to-front
    projectedPoints.sort((a, b) => a.z.compareTo(b.z));

    // Draw all points
    final Paint paint = Paint()..style = PaintingStyle.fill;
    const baseSize = 1.35;
    
    for (int i = 0; i < projectedPoints.length; i++) {
        final p = projectedPoints[i];
        
        // Perspective projection
        final viewZ = p.z * radius + radius * 1.2;
        final depth = fov / (fov + viewZ);
        
        final x2 = cx + (p.x * radius) * depth;
        final y2 = cy + (p.y * radius) * depth;
        
        // Size and opacity based on depth and volume
        final sizeScale = (baseSize + p.amp * 1.2) * (0.65 + depth * 0.7);
        final facing = (p.z + 1.0) * 0.5;
        final rawAlpha = 0.10 + p.amp * 0.55 + facing * 0.25;
        final alpha = rawAlpha.clamp(0.1, 0.95) * opacity;
        
        paint.color = color.withValues(alpha: alpha);
        canvas.drawCircle(Offset(x2, y2), sizeScale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) {
     const threshold = 0.01;
     // Repaint if time changes (always) or audio data changes
     return (oldDelegate.time - time).abs() > 0.001 ||
            (oldDelegate.bass - bass).abs() > threshold ||
            (oldDelegate.amplitude - amplitude).abs() > threshold ||
            oldDelegate.color != color ||
            oldDelegate.opacity != opacity;
  }
}

/// Helper class for points after projection calculation
class _ProjectedPoint {
    final int originalIndex; // 'i' in HTML, used for rotation offset
    final double x;
    final double y;
    final double z;
    final double amp;

    const _ProjectedPoint(this.originalIndex, this.x, this.y, this.z, this.amp);
}
