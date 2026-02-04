import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

/// Real-time FFT analysis on Android using Native Visualizer.
class AndroidFFTService {
  static AndroidFFTService? _instance;
  static AndroidFFTService get instance => _instance ??= AndroidFFTService._();

  AndroidFFTService._();

  static const _methodChannel = MethodChannel('com.nautune.audio_fft/methods');
  static const _eventChannel = EventChannel('com.nautune.audio_fft/events');

  StreamSubscription? _eventSubscription;
  bool _initialized = false;
  int? _currentSessionId;

  // FFT output stream
  final _fftController = BehaviorSubject<AndroidFFTData>.seeded(AndroidFFTData.zero);
  Stream<AndroidFFTData> get fftStream => _fftController.stream;

  /// Initialize the Android FFT service
  Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    // Nothing to do until we have a session ID
  }

  /// Start visualizer for a specific audio session ID
  Future<void> startVisualizer(int sessionId) async {
    if (!Platform.isAndroid) return;
    
    // If we're already visualizing this session, do nothing
    if (_currentSessionId == sessionId && _initialized) return;
    
    _currentSessionId = sessionId;

    try {
      // Setup event listener if not already done
      _eventSubscription ??= _eventChannel
            .receiveBroadcastStream()
            .listen(_handleFFTEvent, onError: _handleError);

      await _methodChannel.invokeMethod('startVisualizer', {'sessionId': sessionId});
      _initialized = true;
      debugPrint('🎵 Android FFT: Custom Visualizer started for session $sessionId');
    } catch (e) {
      debugPrint('🎵 Android FFT: Start error - $e');
      // Likely permission denied if not handled
    }
  }

  /// Stop the visualizer
  Future<void> stopVisualizer() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _methodChannel.invokeMethod('stopVisualizer');
      _currentSessionId = null;
    } catch (e) {
      debugPrint('🎵 Android FFT: Stop error - $e');
    }
  }

  void _handleFFTEvent(dynamic event) {
    if (event is Map) {
      final bass = (event['bass'] as num?)?.toDouble() ?? 0.0;
      final mid = (event['mid'] as num?)?.toDouble() ?? 0.0;
      final treble = (event['treble'] as num?)?.toDouble() ?? 0.0;
      final amplitude = (event['amplitude'] as num?)?.toDouble() ?? 0.0;
      final spectrumRaw = event['spectrum'] as List<dynamic>?;
      final spectrum = spectrumRaw?.map((e) => (e as num).toDouble()).toList() ?? [];
      final sampleRate = (event['sampleRate'] as num?)?.toInt() ?? 44100;

      _fftController.add(AndroidFFTData(
        bass: bass.clamp(0.0, 1.0),
        mid: mid.clamp(0.0, 1.0),
        treble: treble.clamp(0.0, 1.0),
        amplitude: amplitude.clamp(0.0, 1.0),
        spectrum: spectrum,
        sampleRate: sampleRate,
      ));
    }
  }

  void _handleError(dynamic error) {
    debugPrint('🎵 Android FFT: Stream error - $error');
  }

  void dispose() {
    stopVisualizer();
    _eventSubscription?.cancel();
    _fftController.close();
    _initialized = false;
    _instance = null;
  }
}

/// FFT analysis result from Android
class AndroidFFTData {
  final double bass;
  final double mid;
  final double treble;
  final double amplitude;
  final List<double> spectrum;
  final int sampleRate;

  const AndroidFFTData({
    required this.bass,
    required this.mid,
    required this.treble,
    required this.amplitude,
    this.spectrum = const [],
    this.sampleRate = 44100,
  });

  static const zero = AndroidFFTData(
    bass: 0,
    mid: 0,
    treble: 0,
    amplitude: 0,
    spectrum: [],
    sampleRate: 44100,
  );
}
