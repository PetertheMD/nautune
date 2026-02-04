import 'dart:io' show Platform;
import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'base_visualizer.dart';

// The classic bars everyone knows and loves. Plus peak indicators.
class SpectrumBarsVisualizer extends BaseVisualizer {
  const SpectrumBarsVisualizer({
    super.key,
    required super.audioService,
    super.opacity = 0.6,
    super.isVisible = true,
  });

  @override
  State<SpectrumBarsVisualizer> createState() => _SpectrumBarsVisualizerState();
}

class _SpectrumBarsVisualizerState extends BaseVisualizerState<SpectrumBarsVisualizer> {
  static const int _barCount = 48;

  // Peak hold values (fall slowly)
  final List<double> _peakValues = List<double>.filled(_barCount, 0.0);
  // Remaining hold time in seconds for each bar
  final List<double> _peakHoldTimes = List<double>.filled(_barCount, 0.0);
  
  static const double _peakHoldDurationSeconds = 0.5;
  static const double _peakFallSpeedSeconds = 0.6;
  
  DateTime? _lastUpdateTime;

  @override
  int get spectrumBarCount => _barCount;

  void _updatePeaks(List<double> bars) {
    final now = DateTime.now();
    final dt = _lastUpdateTime == null 
        ? 0.016 
        : now.difference(_lastUpdateTime!).inMicroseconds / 1000000.0;
    _lastUpdateTime = now;

    // Cap dt to prevent huge jumps if paused/backgrounded
    final safeDt = dt > 0.1 ? 0.1 : dt;

    for (int i = 0; i < _barCount && i < bars.length; i++) {
        final value = bars[i];
        
        // Rise instantly, fall slowly
        if (value >= _peakValues[i]) {
            _peakValues[i] = value;
            _peakHoldTimes[i] = _peakHoldDurationSeconds;
        } else if (_peakHoldTimes[i] > 0) {
            // Hold the peak for a moment
            _peakHoldTimes[i] -= safeDt;
        } else {
            // Drop it like it's hot (but slowly)
            _peakValues[i] = max(0.0, _peakValues[i] - _peakFallSpeedSeconds * safeDt);
        }
    }
  }

  @override
  Widget buildVisualizer(BuildContext context) {
    final bars = getSpectrumBars(_barCount);
    _updatePeaks(bars);

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return RepaintBoundary(
      child: CustomPaint(
        painter: _SpectrumBarsPainter(
          bars: bars,
          peaks: _peakValues,
          primaryColor: primaryColor,
          opacity: widget.opacity,
          bass: smoothBass,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SpectrumBarsPainter extends CustomPainter {
  final List<double> bars;
  final List<double> peaks;
  final Color primaryColor;
  final double opacity;
  final double bass;

  late final Paint _barPaint;
  late final Paint _peakPaint;
  late final Paint _bottomGlowPaint;

  static const MaskFilter _blurFilter8 = MaskFilter.blur(BlurStyle.normal, 8);

  // Pre-computed color data (regenerated when primaryColor changes)
  static Color? _cachedPrimaryColor;
  static final List<Color> _baseColors = List.filled(48, Colors.black);
  static final List<Color> _brightColors = List.filled(48, Colors.white);

  _SpectrumBarsPainter({
    required this.bars,
    required this.peaks,
    required this.primaryColor,
    required this.opacity,
    required this.bass,
  }) {
    _barPaint = Paint()..style = PaintingStyle.fill;
    _peakPaint = Paint()..style = PaintingStyle.fill;
    _bottomGlowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = _blurFilter8;

    // Regenerate color arrays if the theme changed
    if (_cachedPrimaryColor != primaryColor) {
      _cachedPrimaryColor = primaryColor;
      final primaryHsl = HSLColor.fromColor(primaryColor);
      final baseHue = primaryHsl.hue;
      final baseSat = primaryHsl.saturation;
      
      for (int i = 0; i < 48; i++) {
        final hueShift = -30 + (i / 48) * 70;
        final hue = (baseHue + hueShift) % 360;
        
        // Base color (minimum value)
        _baseColors[i] = HSLColor.fromAHSL(
          1.0, 
          hue, 
          baseSat * 0.85 * 0.8, 
          0.45 + (1 - i / 48) * 0.15
        ).toColor();
        
        // Bright color (maximum value)
        _brightColors[i] = HSLColor.fromAHSL(
          1.0, 
          hue, 
          baseSat * 0.85, 
          (0.45 + (1 - i / 48) * 0.15 + 0.25).clamp(0.0, 0.85)
        ).toColor();
      }
    }
  }

  // Fast color generation using lerp between pre-computed colors
  Color _getBarColor(int index, double value) {
    final i = index.clamp(0, 47);
    return Color.lerp(_baseColors[i], _brightColors[i], value) ?? _baseColors[i];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    final barCount = bars.length;
    const spacing = 2.0;
    final totalSpacing = spacing * (barCount - 1);
    final barWidth = (size.width - totalSpacing) / barCount;

    final effectiveHeight =
        Platform.isIOS && size.height > size.width ? size.height * 0.8 : size.height;

    final bassBoost = 1.0 + bass * 0.4;

    // Ensure no stale shader leaks between frames/passes
    // Draw bars
    for (int i = 0; i < barCount; i++) {
      final value = bars[i];
      if (value < 0.01) continue; // Optimization: skip invisible bars

      final x = i * (barWidth + spacing);
      final barHeight = value * effectiveHeight * 0.95 * bassBoost;

      final color = _getBarColor(i, value);
      
      // Simple transparent glow on bars (faster than separate blur pass)
      _barPaint
        ..shader = null
        ..color = color.withValues(alpha: opacity * 0.85);

      final barRect = Rect.fromLTWH(
        x,
        size.height - barHeight,
        barWidth,
        barHeight,
      );

      final rrect = RRect.fromRectAndRadius(
        barRect,
        Radius.circular(barWidth / 3),
      );
      canvas.drawRRect(rrect, _barPaint);
    }

    // Peak indicators
    for (int i = 0; i < barCount && i < peaks.length; i++) {
      final peakValue = peaks[i];
      if (peakValue < 0.05) continue;

      final x = i * (barWidth + spacing);
      final peakY = size.height - (peakValue * effectiveHeight * 0.85);
      final color = _getBarColor(i, peakValue);

      _peakPaint
        ..shader = null
        ..color = color.withValues(alpha: opacity * 0.9);

      final peakRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, peakY - 3, barWidth, 3),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(peakRect, _peakPaint);
    }

    // Bottom glow on bass hits
    if (bass > 0.3) {
      final glowHeight = effectiveHeight * 0.15;
      final bottomRect =
          Rect.fromLTWH(0, size.height - glowHeight, size.width, glowHeight);

      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          primaryColor.withValues(alpha: opacity * bass * 0.45),
          Colors.transparent,
        ],
      );

      _bottomGlowPaint.shader = gradient.createShader(bottomRect);
      canvas.drawRect(bottomRect, _bottomGlowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumBarsPainter old) {
    const tolerance = 0.001;

    if (bars.length != old.bars.length) return true;
    if (peaks.length != old.peaks.length) return true;

    if ((bass - old.bass).abs() > tolerance) return true;
    if ((opacity - old.opacity).abs() > tolerance) return true;
    if (primaryColor != old.primaryColor) return true;

    for (int i = 0; i < bars.length; i++) {
      if ((bars[i] - old.bars[i]).abs() > tolerance) return true;
    }
    for (int i = 0; i < peaks.length; i++) {
      if ((peaks[i] - old.peaks[i]).abs() > tolerance) return true;
    }
    return false;
  }
}
