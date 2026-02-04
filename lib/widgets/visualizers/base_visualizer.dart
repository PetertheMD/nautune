import 'dart:async' show StreamSubscription;
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/audio_player_service.dart';
import '../../services/pulseaudio_fft_service.dart';
import '../../services/ios_fft_service.dart';
import '../../services/power_mode_service.dart';

/// Abstract base class for all audio visualizers.
/// Provides shared FFT subscription logic, animation control, and value smoothing.
abstract class BaseVisualizer extends StatefulWidget {
  const BaseVisualizer({
    super.key,
    required this.audioService,
    this.opacity = 0.6,
  });

  final AudioPlayerService audioService;
  final double opacity;
}

/// Base state class with FFT subscription and smoothing logic.
/// Subclasses must implement [buildVisualizer] to render their specific visualization.
abstract class BaseVisualizerState<T extends BaseVisualizer> extends State<T>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;

  // Smoothed values used by visualizers
  double smoothBass = 0.0;
  double smoothMid = 0.0;
  double smoothTreble = 0.0;
  double smoothAmplitude = 0.0;
  List<double> smoothSpectrum = [];

  // Target values from FFT or metadata
  double _targetBass = 0.0;
  double _targetMid = 0.0;
  double _targetTreble = 0.0;
  double _targetAmplitude = 0.0;
  List<double> _targetSpectrum = [];

  // Frame rate throttling
  DateTime _lastFrameTime = DateTime.now();
  static const _frameIntervalReal = Duration(milliseconds: 16);
  static const _frameIntervalFallback = Duration(milliseconds: 33);

  double lastPaintedTime = 0;

  StreamSubscription? _playingSubscription;
  StreamSubscription? _frequencySubscription;
  StreamSubscription? _fftSubscription;
  StreamSubscription? _lowPowerModeSubscription;
  
  /// iOS Low Power Mode state (disables visualization when true)
  bool _isLowPowerMode = false;

  bool get usePulseAudioFFT =>
      Platform.isLinux && PulseAudioFFTService.instance.isAvailable;
  bool get useIOSFFT => Platform.isIOS && IOSFFTService.instance.isAvailable;
  bool get useRealFFT => usePulseAudioFFT || useIOSFFT;

  /// Number of spectrum bars to use (subclasses can override)
  int get spectrumBarCount => 64;

  // Frequency range for bar mapping (20Hz to 14kHz)
  static const double _minHz = 20.0;
  static const double _maxHz = 14000.0;

  // Bar smoothing cache (fast attack/decay, very light to avoid latency).
  List<double> _barEma = const [];

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _initFFTSource();

    _playingSubscription = widget.audioService.playingStream.listen((playing) {
      if (!mounted) return;
      if (playing) {
        animationController.repeat();
      } else {
        animationController.stop();
      }
    });

    if (widget.audioService.isPlaying) {
      animationController.repeat();
    }
    
    // Listen for iOS Low Power Mode to disable visualizations
    if (Platform.isIOS) {
      _isLowPowerMode = PowerModeService.instance.isLowPowerMode;
      _lowPowerModeSubscription = PowerModeService.instance.lowPowerModeStream.listen((lowPower) {
        if (mounted) {
          setState(() => _isLowPowerMode = lowPower);
        }
      });
    }
  }

  void _initFFTSource() {
    // 1. Linux PulseAudio (Real FFT)
    if (usePulseAudioFFT) {
      _fftSubscription = PulseAudioFFTService.instance.fftStream.listen((fft) {
        _targetBass = fft.bass * 0.92;
        _targetMid = fft.mid;
        _targetTreble = fft.treble;
        _targetAmplitude = fft.amplitude;
        _targetSpectrum = fft.spectrum;
      });
      return;
    }

    // 2. iOS Native FFT
    if (useIOSFFT) {
      _fftSubscription = IOSFFTService.instance.fftStream.listen((fft) {
        const iosScale = 0.65;
        _targetBass = fft.bass * iosScale;
        _targetMid = fft.mid * iosScale;
        _targetTreble = fft.treble * iosScale;
        _targetAmplitude = fft.amplitude * iosScale;
        // Generate a simple spectrum from 3 bands
        _targetSpectrum = _generateFakeSpectrum(_targetBass, _targetMid, _targetTreble);
      });
      return;
    }

    // 3. Fallback to basic frequency bands
    _frequencySubscription = widget.audioService.frequencyBandsStream.listen((bands) {
      _targetBass = bands.bass;
      _targetMid = bands.mid;
      _targetTreble = bands.treble;
      _targetAmplitude = ((bands.bass + bands.mid + bands.treble) / 3).clamp(0.0, 1.0);
      _targetSpectrum = _generateFakeSpectrum(bands.bass, bands.mid, bands.treble);
    });
  }

  List<double> _generateFakeSpectrum(double bass, double mid, double treble) {
    final spectrum = <double>[];
    final count = spectrumBarCount;

    for (int i = 0; i < count; i++) {
      final ratio = i / count;
      double value;

      if (ratio < 0.2) {
        value = bass * (1.0 - ratio * 2);
      } else if (ratio < 0.6) {
        final midRatio = (ratio - 0.2) / 0.4;
        value = mid * (0.7 + 0.3 * (1.0 - (midRatio - 0.5).abs() * 2));
      } else {
        final trebleRatio = (ratio - 0.6) / 0.4;
        value = treble * (1.0 - trebleRatio * 0.5);
      }

      spectrum.add(value.clamp(0.0, 1.0));
    }

    return spectrum;
  }

  @override
  void dispose() {
    _fftSubscription?.cancel();
    _frequencySubscription?.cancel();
    _playingSubscription?.cancel();
    _lowPowerModeSubscription?.cancel();
    animationController.dispose();
    super.dispose();
  }

  // Update and smooth values
  void updateSmoothedValues() {
    final now = DateTime.now();
    final frameInterval = useRealFFT ? _frameIntervalReal : _frameIntervalFallback;
    if (now.difference(_lastFrameTime) < frameInterval) return;
    _lastFrameTime = now;

    if (useRealFFT) {
      // Light band smoothing only
      const attack = 0.75;
      const decay = 0.35;

      smoothBass += (_targetBass - smoothBass) * (_targetBass > smoothBass ? attack : decay);
      smoothMid += (_targetMid - smoothMid) * (_targetMid > smoothMid ? attack : decay);
      smoothTreble += (_targetTreble - smoothTreble) * (_targetTreble > smoothTreble ? attack : decay);
      smoothAmplitude += (_targetAmplitude - smoothAmplitude) * (_targetAmplitude > smoothAmplitude ? attack : decay);

      // Spectrum direct
      smoothSpectrum = _targetSpectrum;
    } else {
      final attackFactor = Platform.isIOS ? 0.4 : 0.3;
      final decayFactor = Platform.isIOS ? 0.35 : 0.08;

      smoothBass += (_targetBass - smoothBass) *
          (_targetBass > smoothBass ? attackFactor : decayFactor);
      smoothMid += (_targetMid - smoothMid) *
          (_targetMid > smoothMid ? attackFactor : decayFactor);
      smoothTreble += (_targetTreble - smoothTreble) *
          (_targetTreble > smoothTreble ? attackFactor : decayFactor);
      smoothAmplitude += (_targetAmplitude - smoothAmplitude) *
          (_targetAmplitude > smoothAmplitude ? attackFactor : decayFactor);

      _updateSmoothedSpectrum(attackFactor, decayFactor);
    }

    lastPaintedTime = animationController.value * 10;
  }

  void _updateSmoothedSpectrum(double attackFactor, double decayFactor) {
    if (_targetSpectrum.isEmpty) return;

    if (smoothSpectrum.length != _targetSpectrum.length) {
      smoothSpectrum = List<double>.filled(_targetSpectrum.length, 0.0);
    }

    for (int i = 0; i < _targetSpectrum.length; i++) {
      final target = _targetSpectrum[i];
      final current = smoothSpectrum[i];
      smoothSpectrum[i] += (target - current) *
          (target > current ? attackFactor : decayFactor);
    }
  }

  // Get smoothed bars for visualization
  // Uses log-frequency spacing for a natural look
  List<double> getSpectrumBars(int barCount) {
    if (barCount <= 0) return const [];

    if (smoothSpectrum.isEmpty) {
      return _generateBarsFromBands(barCount);
    }

    if (_barEma.length != barCount) {
      _barEma = List<double>.filled(barCount, 0.0);
    }

    final rawBars = _buildLogFrequencyBarsFromSpectrum(
      spectrum: smoothSpectrum,
      barCount: barCount,
      minHz: _minHz,
      maxHz: _maxHz,
    );

    // Very light smoothing to avoid shimmer (doesn't add much latency)
    final attack = useRealFFT ? 0.55 : 0.40;
    final decay = useRealFFT ? 0.25 : 0.18;

    for (int i = 0; i < barCount; i++) {
      final x = rawBars[i];
      final prev = _barEma[i];
      final a = (x > prev) ? attack : decay;
      _barEma[i] = prev + a * (x - prev);
    }

    return _barEma;
  }

  // Convert raw spectrum to log-spaced bars
  // This matches how human ears perceive pitch
  List<double> _buildLogFrequencyBarsFromSpectrum({
    required List<double> spectrum,
    required int barCount,
    required double minHz,
    required double maxHz,
  }) {
    final len = spectrum.length;
    if (len == 0) return List<double>.filled(barCount, 0.0);

    const nyquist = 22050.0;
    final lo = minHz.clamp(20.0, maxHz - 100.0);
    final hi = maxHz.clamp(lo + 100.0, nyquist);

    // Helpers for sampling
    double getBinIndex(int barIdx) {
      final t = barIdx / barCount;
      final hz = lo * math.pow(hi / lo, t).toDouble();
      return (hz / nyquist) * len;
    }

    double sampleSpectrum(double binIdx) {
      final idx = binIdx.clamp(0.0, len - 1.0);
      final i = idx.floor();
      final frac = idx - i;
      if (i >= len - 1) return spectrum[len - 1];
      // Linear interpolation between bins
      return spectrum[i] * (1.0 - frac) + spectrum[i + 1] * frac;
    }

    // Compression
    const k = 10.0;
    const global = 0.80;
    double compress(double val) {
      final y = math.log(1 + k * (val * val)) / math.log(1 + k);
      return math.pow(y.clamp(0.0, 1.0), 0.9).toDouble();
    }

    final bars = List<double>.filled(barCount, 0.0);

    for (int i = 0; i < barCount; i++) {
      final idx0 = getBinIndex(i);
      final idx1 = getBinIndex(i + 1);
      
      double val;
      // Sample or average the spectrum for this bar
      if ((idx1 - idx0) > 1.0) {
        double sum = 0.0;
        int count = 0;
        for (int b = idx0.floor(); b <= idx1.floor() && b < len; b++) {
          sum += spectrum[b];
          count++;
        }
        val = (compress(sum / count) * global).clamp(0.0, 1.0);
      } else {
        // High resolution region (Bass): use precise interpolated sample
        final centerIdx = (idx0 + idx1) / 2.0;
        val = (compress(sampleSpectrum(centerIdx)) * global).clamp(0.0, 1.0);
      }

      // Reduce bass gain by ~8% (first 30% of bars)
      if (i < barCount * 0.3) {
        val *= 0.92;
      }
      
      bars[i] = val;
    }

    return bars;
  }

  List<double> _generateBarsFromBands(int barCount) {
    final bars = <double>[];

    for (int i = 0; i < barCount; i++) {
      final ratio = i / barCount;
      double value;

      if (ratio < 0.25) {
        final variation = 0.7 + 0.3 * (1.0 - (ratio / 0.25 - 0.5).abs() * 2);
        value = smoothBass * variation * 1.2;
      } else if (ratio < 0.6) {
        final midRatio = (ratio - 0.25) / 0.35;
        final variation = 0.6 + 0.4 * (1.0 - (midRatio - 0.5).abs() * 2);
        value = smoothMid * variation * 1.1;
      } else {
        final trebleRatio = (ratio - 0.6) / 0.4;
        final variation = 0.5 + 0.5 * (1.0 - trebleRatio * 0.5);
        value = smoothTreble * variation;
      }

      value = (value * (0.7 + smoothAmplitude * 0.5)).clamp(0.0, 1.0);
      bars.add(value);
    }

    return bars;
  }

  @override
  Widget build(BuildContext context) {
    // Disable visualization in iOS Low Power Mode for battery efficiency
    if (Platform.isIOS && _isLowPowerMode) {
      return const SizedBox.shrink();
    }
    
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        updateSmoothedValues();
        return buildVisualizer(context);
      },
    );
  }

  /// Build the specific visualizer widget. Called every frame.
  Widget buildVisualizer(BuildContext context);
}
