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
    super.isVisible = true,
  });

  /// Graphics quality level (affects particle count)
  final GlobeQuality quality;

  @override
  State<GlobeVisualizer> createState() => _GlobeVisualizerState();
}

class _GlobeVisualizerState extends BaseVisualizerState<GlobeVisualizer> {
  // Points array - regenerated when quality changes
  List<_GlobePoint> _points = [];

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
    final count = widget.quality.particleCount;
    _points = _generateFibonacciSphere(count);
  }

  // Create an evenly distributed sphere of points
  List<_GlobePoint> _generateFibonacciSphere(int count) {
    final List<_GlobePoint> newPoints = [];
    final goldenAngle = pi * (3.0 - sqrt(5.0));

    for (int i = 0; i < count; i++) {
      // Calculate point position
      final t = i / (count - 1);
      final yy = 1.0 - 2.0 * t;
      final r = sqrt(max(0.0, 1.0 - yy * yy));
      final theta = goldenAngle * i;

      // Convert to Cartesian
      final x = cos(theta) * r;
      final z = sin(theta) * r;

      // Map height to frequency band (0-63)
      final bandIndex = ((yy + 1.0) / 2.0) * 63.0;

      newPoints.add(_GlobePoint(x, yy, z, bandIndex));
    }
    return newPoints;
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
    // Set up rotation based on time (slow, smooth rotation)
    final rotY = time * 0.12; 
    final rotX = sin(time * 0.08) * 0.15;

    _sinY = sin(rotY);
    _cosY = cos(rotY);
    _sinX = sin(rotX);
    _cosX = cos(rotX);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    
    // Scale globe based on screen size (increased 10% from 0.36 to 0.40)
    final radius = min(size.width, size.height) * 0.40;
    
    // Field of view for perspective
    final fov = radius * 2.5;
    
    // Gain/Volume boost
    final audioGain = 1.0 + amplitude * 0.45;

    // 1. Project, rotate, and apply audio boost to each point
    final List<_ProjectedPoint> projectedPoints = [];
    
    for (int i = 0; i < points.length; i++) {
        final p = points[i];
        
        // Calculate amplitude with interpolation
        final binFloat = p.bandIndex;
        final binLow = binFloat.floor().clamp(0, spectrum.length - 1);
        final binHigh = (binLow + 1).clamp(0, spectrum.length - 1);
        final blend = binFloat - binLow;
        
        // Apply frequency-dependent boost to make mids/highs more visible
        // Bass is naturally stronger, so we scale up the response for higher bands
        final freqBoost = 1.0 + (binFloat / 63.0) * 1.2;
        final amp = (spectrum[binLow] * (1.0 - blend) + spectrum[binHigh] * blend) * audioGain * freqBoost;
        
        // Rotate point in 3D space
        // Rotate around X axis (tilt)
        final y1 = p.y * _cosX - p.z * _sinX;
        final z1 = p.y * _sinX + p.z * _cosX;
        
        // Rotate around Y axis (spinning)
        final rx = p.x * _cosY + z1 * _sinY;
        final ry = y1;
        final rz = -p.x * _sinY + z1 * _cosY;
        
        // Push point outward based on volume (pulse effect)
        // Reduced push factor to keep globe shape more consistent
        final push = 1.0 + amp * 0.15;
        final px = rx * push;
        final py = ry * push;
        final pz = rz * push;
        
        projectedPoints.add(_ProjectedPoint(px, py, pz, amp));
    }
    
    // 3. Sort so we draw back-to-front for correct transparency depth
    // This is essential for the 3D effect with semi-transparent particles
    projectedPoints.sort((a, b) => a.z.compareTo(b.z));

    // 4. Draw all points as spheres
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final Paint highlightPaint = Paint()..style = PaintingStyle.fill;
    
    // Smaller base size for a cleaner, less "messy" look
    const baseSize = 1.1; 
    
    for (final p in projectedPoints) {
        // Perspective projection
        final viewZ = p.z * radius + radius * 1.2;
        final depth = fov / (fov + viewZ);
        
        final x2 = cx + (p.x * radius) * depth;
        final y2 = cy + (p.y * radius) * depth;
        
        // Size and opacity based on depth and volume
        // Further points are smaller and dimmer
        final sizeScale = (baseSize + p.amp * 0.9) * (0.6 + depth * 0.8);
        final facing = (p.z + 1.0) * 0.5; // 0.0 at back, 1.0 at front
        
        final rawAlpha = 0.12 + p.amp * 0.6 + facing * 0.25;
        final alpha = rawAlpha.clamp(0.05, 0.98) * opacity;
        
        // Main sphere body
        paint.color = color.withValues(alpha: alpha);
        canvas.drawCircle(Offset(x2, y2), sizeScale, paint);
        
        // Sphere highlight (makes it look 3D and "clean")
        if (sizeScale > 1.0) {
          final highlightAlpha = (alpha * 0.5).clamp(0.0, 1.0);
          highlightPaint.color = Colors.white.withValues(alpha: highlightAlpha);
          
          // Offset highlight to top-left of the particle
          final hOffset = sizeScale * 0.3;
          canvas.drawCircle(
            Offset(x2 - hOffset, y2 - hOffset), 
            sizeScale * 0.35, 
            highlightPaint
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) {
     return oldDelegate.time != time ||
            oldDelegate.bass != bass ||
            oldDelegate.amplitude != amplitude ||
            oldDelegate.color != color ||
            oldDelegate.opacity != opacity ||
            oldDelegate.spectrum != spectrum;
  }
}

/// Helper class for points after projection calculation
class _ProjectedPoint {
    final double x;
    final double y;
    final double z;
    final double amp;

    const _ProjectedPoint(this.x, this.y, this.z, this.amp);
}
