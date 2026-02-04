import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

// Listens to the system audio on Linux and calculates frequency data
// Optimized for low latency so the visuals actually match the beat
class PulseAudioFFTService {
  static PulseAudioFFTService? _instance;
  static PulseAudioFFTService get instance => _instance ??= PulseAudioFFTService._();

  PulseAudioFFTService._();

  Isolate? _fftIsolate;
  ReceivePort? _isolateReceivePort;

  // FFT output stream
  final _fftController = BehaviorSubject<FFTData>.seeded(FFTData.zero);
  Stream<FFTData> get fftStream => _fftController.stream;
  FFTData get currentFFT => _fftController.value;

  /// Linux only
  bool get isAvailable => Platform.isLinux;

  // ---------------- Configuration ----------------

  // Audio settings
  static const int _sampleRate = 44100;
  static const int _fftSize = 1024;      // ~23ms window for snappy response
  static const int _hopSize = _fftSize ~/ 2; // 50% overlap

  // ---------------- Public API ----------------

  /// Initialize and find PulseAudio monitor source
  Future<bool> initialize() async {
    if (!Platform.isLinux) return false;

    try {
      final whichResult = await Process.run('which', ['parec']);
      if (whichResult.exitCode != 0) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Start capturing system audio for FFT analysis using parec
  Future<void> startCapture() async {
    if (_fftIsolate != null) return;

    try {
      _isolateReceivePort = ReceivePort();
      final monitorSource = await _findMonitorSource();
      
      if (monitorSource == null) {
        debugPrint('PulseAudio FFT: No monitor source found');
        return;
      }

      // Spawn the isolated worker
      _fftIsolate = await Isolate.spawn(
        _fftIsolateEntryPoint,
        _FFTIsolateInitData(
          sendPort: _isolateReceivePort!.sendPort,
          monitorSource: monitorSource,
          sampleRate: _sampleRate,
          fftSize: _fftSize,
          hopSize: _hopSize,
        ),
      );

      // Listen for data from the isolate
      _isolateReceivePort!.listen((message) {
        if (message is FFTData) {
          _fftController.add(message);
        } else if (message is String) {
          // Error or log message
          debugPrint('PulseAudio Isolate: $message');
        }
      });

    } catch (e) {
      debugPrint('PulseAudio FFT start failed: $e');
      stopCapture();
    }
  }

  /// Stop capturing
  Future<void> stopCapture() async {
    _isolateReceivePort?.close();
    _isolateReceivePort = null;
    
    _fftIsolate?.kill(priority: Isolate.immediate);
    _fftIsolate = null;
    
    _fftController.add(FFTData.zero);
  }

  void dispose() {
    stopCapture();
    _fftController.close();
    _instance = null;
  }

  // Helper to find audio source (runs on main thread once)
  Future<String?> _findMonitorSource() async {
    try {
      String? defaultSink;
      final infoResult = await Process.run('pactl', ['get-default-sink']);
      if (infoResult.exitCode == 0) {
        defaultSink = (infoResult.stdout as String).trim();
      }

      final result = await Process.run('pactl', ['list', 'sources', 'short']);
      if (result.exitCode != 0) return null;

      final output = result.stdout as String;
      final lines = output.split('\n');

      if (defaultSink != null && defaultSink.isNotEmpty) {
        final expectedMonitor = '$defaultSink.monitor';
        for (final line in lines) {
          if (line.contains(expectedMonitor)) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length >= 2) return parts[1];
          }
        }
      }

      for (final line in lines) {
        if (line.contains('.monitor')) {
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 2) return parts[1];
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

// Data packet for initializing the isolate
class _FFTIsolateInitData {
  final SendPort sendPort;
  final String monitorSource;
  final int sampleRate;
  final int fftSize;
  final int hopSize;

  _FFTIsolateInitData({
    required this.sendPort,
    required this.monitorSource,
    required this.sampleRate,
    required this.fftSize,
    required this.hopSize,
  });
}

// ---------------- ISOLATE LOGIC ----------------

// Entry point for the background isolate
void _fftIsolateEntryPoint(_FFTIsolateInitData initData) async {
  final sendPort = initData.sendPort;
  
  // Frequency bands
  const double bassLoHz = 60.0;
  const double bassHiHz = 250.0;
  const double midHiHz = 4000.0;

  // Visual Reference (AGC)
  const double headroomDb = 18.0;
  const double rangeDb = 75.0;
  const double refLoHz = 80.0;
  const double refHiHz = 8000.0;

  // Smoothing
  const double gammaSpectrum = 0.85;
  const double gammaBands = 0.95;

  Process? parecProcess;
  
  try {
    // Start parec inside the isolate
    parecProcess = await Process.start('parec', [
      '--device=${initData.monitorSource}',
      '--format=s16le',
      '--channels=1',
      '--rate=${initData.sampleRate}',
      '--latency-msec=20', // Increased to 20ms for stability
      '--process-time-msec=5',
    ]);

    final ring = Int16List(initData.fftSize);
    int ringWrite = 0;
    int totalSamples = 0;
    int samplesSinceLastFft = 0;
    int? pendingByte;

    // Smoothing state
    double ampEma = 0.0;
    double bassEma = 0.0;
    double midEma = 0.0;
    double trebleEma = 0.0;
    final specEma = Float64List(initData.fftSize ~/ 2);
    double refPeakDbEma = -40.0;
    
    // Window function
    final hann = _buildHann(initData.fftSize);

    // Helpers
    int hzToBin(double hz) {
      final nyquist = initData.sampleRate / 2.0;
      final clamped = hz.clamp(0.0, nyquist);
      final bin = (clamped * initData.fftSize / initData.sampleRate).floor();
      return bin.clamp(0, (initData.fftSize ~/ 2) - 1);
    }

    double powerToDb(double power) {
      const eps = 1e-12;
      return 10.0 * math.log(power + eps) / math.ln10;
    }

    double normRelDb(double power) {
      final db = powerToDb(power);
      final topDb = refPeakDbEma + headroomDb;
      final bottomDb = topDb - rangeDb;
      final x = (db - bottomDb) / rangeDb;
      return x.clamp(0.0, 1.0);
    }
    
    double shape(double x, double gamma) => math.pow(x.clamp(0.0, 1.0), gamma).toDouble();

    double smoothAttackDecay(double prev, double x, {required double attack, required double decay}) {
      final a = (x > prev) ? attack : decay;
      return prev + a * (x - prev);
    }

    double bandPower(Float64List mags, int start, int end) {
      if (end <= start) return 0.0;
      final s = start.clamp(0, mags.length);
      final e = end.clamp(s, mags.length);
      if (e <= s) return 0.0;
      double sum = 0.0;
      for (int i = s; i < e; i++) {
        sum += mags[i] * mags[i];
      }
      return sum / (e - s);
    }

    // Process loop
    await for (final incomingData in parecProcess.stdout) {
      if (incomingData.isEmpty) continue;

      final Uint8List rawBytes = incomingData is Uint8List
          ? incomingData
          : Uint8List.fromList(incomingData);

      Uint8List bytes = rawBytes;
      if (pendingByte != null) {
        final b = Uint8List(rawBytes.length + 1);
        b[0] = pendingByte;
        b.setRange(1, b.length, rawBytes);
        bytes = b;
        pendingByte = null;
      }

      if (bytes.lengthInBytes.isOdd) {
        pendingByte = bytes[bytes.lengthInBytes - 1];
        bytes = bytes.sublist(0, bytes.lengthInBytes - 1);
      }

      final bd = ByteData.sublistView(bytes);
      final int sampleCount = bd.lengthInBytes ~/ 2;

      for (int i = 0; i < sampleCount; i++) {
        ring[ringWrite] = bd.getInt16(i * 2, Endian.little);
        ringWrite = (ringWrite + 1) & (initData.fftSize - 1);
      }
      
      totalSamples += sampleCount;
      samplesSinceLastFft += sampleCount;

      if (totalSamples >= initData.fftSize && samplesSinceLastFft >= initData.hopSize) {
        samplesSinceLastFft = 0;

        // Process frame
        final frame = Float64List(initData.fftSize);
        int idx = ringWrite; // ringWrite is oldest sample if loop just wrapped? No, ringWrite is where we WRITE. 
        // Wait, normally we read from ringWrite (oldest) to new.
        // If ringWrite points to next write slot, then ringWrite IS the oldest sample index. Correct.
        
        double mean = 0.0;
        for (int i = 0; i < initData.fftSize; i++) {
          final v = ring[idx] / 32768.0;
          frame[i] = v;
          mean += v;
          idx = (idx + 1) & (initData.fftSize - 1);
        }
        mean /= initData.fftSize;

        // DC + RMS
        double sumSquares = 0.0;
        for (int i = 0; i < initData.fftSize; i++) {
          frame[i] -= mean;
          sumSquares += frame[i] * frame[i];
        }
        final rms = math.sqrt(sumSquares / initData.fftSize);
        
        // Apply Window
        for (int i = 0; i < initData.fftSize; i++) {
          frame[i] *= hann[i];
        }

        // FFT
        final mags = _fftMagnitude(frame);

        // AGC Update
        final refLo = hzToBin(refLoHz);
        final refHi = hzToBin(refHiHz);
        double peakP = 0.0;
        for (int i = refLo; i < refHi; i++) {
          final m = mags[i];
          if (m * m > peakP) peakP = m * m;
        }
        refPeakDbEma = smoothAttackDecay(refPeakDbEma, powerToDb(peakP), attack: 0.22, decay: 0.06);

        // Bands
        final b0 = hzToBin(bassLoHz);
        final b1 = hzToBin(bassHiHz);
        final m1 = hzToBin(midHiHz);

        final bassIn = shape(normRelDb(bandPower(mags, b0, b1)), gammaBands);
        final midIn = shape(normRelDb(bandPower(mags, b1, m1)), gammaBands);
        final trebIn = shape(normRelDb(bandPower(mags, m1, mags.length)), gammaBands);

        bassEma = smoothAttackDecay(bassEma, bassIn, attack: 0.60, decay: 0.28);
        midEma = smoothAttackDecay(midEma, midIn, attack: 0.60, decay: 0.28);
        trebleEma = smoothAttackDecay(trebleEma, trebIn, attack: 0.60, decay: 0.28);
        ampEma = smoothAttackDecay(ampEma, rms, attack: 0.55, decay: 0.22);

        // Spectrum
        const specAlpha = 0.65;
        final visualSpectrum = List<double>.filled(mags.length, 0.0);
        for (int i = 0; i < mags.length; i++) {
          final x = shape(normRelDb(mags[i] * mags[i]), gammaSpectrum);
          specEma[i] = specEma[i] + specAlpha * (x - specEma[i]);
          visualSpectrum[i] = specEma[i];
        }

        sendPort.send(FFTData(
          bass: bassEma,
          mid: midEma,
          treble: trebleEma,
          amplitude: (ampEma * 2.0).clamp(0.0, 1.0),
          spectrum: visualSpectrum,
        ));
      }
    }
  } catch (e) {
    sendPort.send('Error in isolate: $e');
  } finally {
    parecProcess?.kill();
  }
}

// ---------------- FFT IMPL ----------------

Float64List _buildHann(int n) {
  final w = Float64List(n);
  for (int i = 0; i < n; i++) {
    w[i] = 0.5 - 0.5 * math.cos(2.0 * math.pi * i / (n - 1));
  }
  return w;
}

Float64List _fftMagnitude(Float64List input) {
  final n = input.length;
  final real = Float64List.fromList(input);
  final imag = Float64List(n); // Zero-init

  // Bit-reversal
  for (int i = 1, j = 0; i < n; i++) {
    int bit = n >> 1;
    for (; (j & bit) != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final tr = real[i]; real[i] = real[j]; real[j] = tr;
      final ti = imag[i]; imag[i] = imag[j]; imag[j] = ti;
    }
  }

  // Butterfly
  for (int len = 2; len <= n; len <<= 1) {
    final ang = -2.0 * math.pi / len;
    final wlenR = math.cos(ang);
    final wlenI = math.sin(ang);

    for (int i = 0; i < n; i += len) {
      double wr = 1.0;
      double wi = 0.0;
      final half = len >> 1;
      for (int j = 0; j < half; j++) {
        final u = i + j;
        final v = u + half;
        final vr = real[v] * wr - imag[v] * wi;
        final vi = real[v] * wi + imag[v] * wr;
        real[v] = real[u] - vr;
        imag[v] = imag[u] - vi;
        real[u] = real[u] + vr;
        imag[u] = imag[u] + vi;
        final nwr = wr * wlenR - wi * wlenI;
        wi = wr * wlenI + wi * wlenR;
        wr = nwr;
      }
    }
  }

  // Magnitude
  final halfN = n >> 1;
  final mags = Float64List(halfN);
  final scale = 2.0 / n;
  for (int i = 0; i < halfN; i++) {
    mags[i] = math.sqrt(real[i] * real[i] + imag[i] * imag[i]) * scale;
  }
  return mags;
}

/// FFT analysis result with frequency bands
class FFTData {
  final double bass;
  final double mid;
  final double treble;
  final double amplitude;
  final List<double> spectrum;

  const FFTData({
    required this.bass,
    required this.mid,
    required this.treble,
    required this.amplitude,
    this.spectrum = const [],
  });

  static const zero = FFTData(
    bass: 0,
    mid: 0,
    treble: 0,
    amplitude: 0,
    spectrum: [],
  );
}
