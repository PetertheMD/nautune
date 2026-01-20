import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/equalizer_preset.dart';

/// Abstract equalizer service interface.
/// Currently only supported on Linux via PulseAudio LADSPA.
abstract class EqualizerService {
  /// Get the platform-appropriate equalizer service instance
  static EqualizerService get instance {
    if (Platform.isLinux) {
      return LinuxEqualizerService.instance;
    }
    return _UnsupportedEqualizerService();
  }

  /// Whether EQ is available on this platform
  bool get isAvailable;

  /// Whether EQ is currently enabled
  bool get isEnabled;

  /// Stream of enabled state changes
  Stream<bool> get enabledStream;

  /// Current active preset
  EqualizerPreset get currentPreset;

  /// Stream of preset changes
  Stream<EqualizerPreset> get presetStream;

  /// Current band gains (10 values, -12 to +12 dB)
  List<double> get currentGains;

  /// Initialize the equalizer
  Future<bool> initialize();

  /// Enable or disable the equalizer
  Future<void> setEnabled(bool enabled);

  /// Set a single band's gain (-12 to +12 dB)
  Future<void> setBand(int bandIndex, double gainDb);

  /// Set all band gains at once
  Future<void> setAllBands(List<double> gains);

  /// Apply a preset
  Future<void> applyPreset(EqualizerPreset preset);

  /// Reset to flat response
  Future<void> reset();

  /// Dispose resources
  Future<void> dispose();
}

/// Linux equalizer using PulseAudio LADSPA plugin
class LinuxEqualizerService extends EqualizerService {
  static LinuxEqualizerService? _instance;
  static LinuxEqualizerService get instance => _instance ??= LinuxEqualizerService._();

  LinuxEqualizerService._();

  bool _initialized = false;
  bool _enabled = false;
  EqualizerPreset _currentPreset = BuiltInPresets.flat;
  List<double> _gains = List.filled(10, 0.0);
  int? _moduleId;
  bool _useEqualizerSink = false; // Whether we're using module-equalizer-sink

  // Debounce timer for applying gains (prevents module reload spam)
  Timer? _applyDebounceTimer;
  static const _applyDebounceDelay = Duration(milliseconds: 150);

  final _enabledController = BehaviorSubject<bool>.seeded(false);
  final _presetController = BehaviorSubject<EqualizerPreset>.seeded(BuiltInPresets.flat);

  @override
  bool get isAvailable => Platform.isLinux;

  @override
  bool get isEnabled => _enabled;

  @override
  Stream<bool> get enabledStream => _enabledController.stream;

  @override
  EqualizerPreset get currentPreset => _currentPreset;

  @override
  Stream<EqualizerPreset> get presetStream => _presetController.stream;

  @override
  List<double> get currentGains => List.unmodifiable(_gains);

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    if (!Platform.isLinux) return false;

    try {
      // Check if pactl is available
      final result = await Process.run('which', ['pactl']);
      if (result.exitCode != 0) {
        debugPrint('🎛️ EQ: pactl not found');
        return false;
      }

      _initialized = true;
      debugPrint('🎛️ EQ: Linux equalizer initialized');
      return true;
    } catch (e) {
      debugPrint('🎛️ EQ: Init error: $e');
      return false;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (!_initialized || _enabled == enabled) return;

    try {
      if (enabled) {
        await _loadEqualizerModule();
      } else {
        await _unloadEqualizerModule();
      }
      _enabled = enabled;
      _enabledController.add(_enabled);
      debugPrint('🎛️ EQ: ${enabled ? "Enabled" : "Disabled"}');
    } catch (e) {
      debugPrint('🎛️ EQ: Error setting enabled: $e');
    }
  }

  Future<void> _loadEqualizerModule() async {
    // Load LADSPA multiband EQ module
    // Using mbeq (15-band EQ) or similar
    try {
      final result = await Process.run('pactl', [
        'load-module',
        'module-ladspa-sink',
        'sink_name=nautune_eq',
        'sink_properties=device.description=Nautune_EQ',
        'plugin=mbeq_1197',
        'label=mbeq',
        'control=${_gains.map((g) => g.toString()).join(",")}',
      ]);

      if (result.exitCode == 0) {
        _moduleId = int.tryParse(result.stdout.toString().trim());
        _useEqualizerSink = false;
        debugPrint('🎛️ EQ: Loaded LADSPA module $_moduleId');

        // Set as default sink
        await Process.run('pactl', ['set-default-sink', 'nautune_eq']);
      } else {
        // Fallback: try simpler equalizer approach using module-equalizer-sink
        // This supports real-time updates via dbus/qpaeq
        debugPrint('🎛️ EQ: LADSPA failed, trying equalizer-sink...');
        final fallback = await Process.run('pactl', [
          'load-module',
          'module-equalizer-sink',
          'sink_name=nautune_eq',
        ]);
        if (fallback.exitCode == 0) {
          _moduleId = int.tryParse(fallback.stdout.toString().trim());
          _useEqualizerSink = true;
          debugPrint('🎛️ EQ: Loaded equalizer-sink module $_moduleId');

          // Set as default sink
          await Process.run('pactl', ['set-default-sink', 'nautune_eq']);
        }
      }
    } catch (e) {
      debugPrint('🎛️ EQ: Error loading module: $e');
    }
  }

  Future<void> _unloadEqualizerModule() async {
    if (_moduleId == null) return;

    try {
      await Process.run('pactl', ['unload-module', _moduleId.toString()]);
      debugPrint('🎛️ EQ: Unloaded module $_moduleId');
      _moduleId = null;
    } catch (e) {
      debugPrint('🎛️ EQ: Error unloading module: $e');
    }
  }

  @override
  Future<void> setBand(int bandIndex, double gainDb) async {
    if (bandIndex < 0 || bandIndex >= 10) return;
    _gains[bandIndex] = gainDb.clamp(-12.0, 12.0);
    await _applyGains();
  }

  @override
  Future<void> setAllBands(List<double> gains) async {
    if (gains.length != 10) return;
    _gains = gains.map((g) => g.clamp(-12.0, 12.0)).toList();
    await _applyGains();
  }

  /// Schedule gains to be applied with debouncing
  /// This prevents module reload spam during rapid slider changes
  void _scheduleApplyGains() {
    _applyDebounceTimer?.cancel();
    _applyDebounceTimer = Timer(_applyDebounceDelay, () {
      _applyGainsNow();
    });
  }

  Future<void> _applyGains() async {
    if (!_enabled || _moduleId == null) return;
    _scheduleApplyGains();
  }

  Future<void> _applyGainsNow() async {
    if (!_enabled || _moduleId == null) return;

    try {
      if (_useEqualizerSink) {
        // For module-equalizer-sink, try to use paequalization D-Bus interface
        // This allows real-time updates without audio glitches
        final success = await _applyGainsViaDbus();
        if (success) return;
      }

      // Fallback: For LADSPA module or if D-Bus failed, we need to reload
      // Batch the reload to minimize glitches
      debugPrint('🎛️ EQ: Reloading module with new gains');
      await _unloadEqualizerModule();
      await _loadEqualizerModule();
    } catch (e) {
      debugPrint('🎛️ EQ: Error applying gains: $e');
    }
  }

  /// Apply gains via D-Bus to module-equalizer-sink (real-time, no glitches)
  Future<bool> _applyGainsViaDbus() async {
    try {
      // Try using qpaeq command-line tool to set EQ bands
      // qpaeq is a Python GUI but we can use dbus-send directly
      // The equalizer-sink exposes org.PulseAudio.Ext.Equalizing1 interface

      // Convert 10-band gains to the 15-band format used by module-equalizer-sink
      // Map our 10 bands (31, 63, 125, 250, 500, 1k, 2k, 4k, 8k, 16k) to 15 bands
      final fifteenBands = _expandTo15Bands(_gains);

      // Use dbus-send to set the equalizer coefficients
      final result = await Process.run('dbus-send', [
        '--session',
        '--dest=org.PulseAudio.Ext.Equalizing1',
        '--type=method_call',
        '/org/pulseaudio/equalizing1/equalized',
        'org.PulseAudio.Ext.Equalizing1.Equalizer.SetFilter',
        'uint32:${fifteenBands.length}',
        'array:double:${fifteenBands.join(",")}',
        'double:0.0', // preamp
      ]);

      if (result.exitCode == 0) {
        debugPrint('🎛️ EQ: Applied gains via D-Bus');
        return true;
      }
    } catch (e) {
      debugPrint('🎛️ EQ: D-Bus update failed: $e');
    }
    return false;
  }

  /// Expand 10-band gains to 15-band format
  List<double> _expandTo15Bands(List<double> tenBands) {
    // 10-band: 31, 63, 125, 250, 500, 1k, 2k, 4k, 8k, 16k
    // 15-band: 25, 40, 63, 100, 160, 250, 400, 630, 1k, 1.6k, 2.5k, 4k, 6.3k, 10k, 16k
    // Simple linear interpolation
    return [
      tenBands[0],                           // 25Hz ≈ 31Hz
      (tenBands[0] + tenBands[1]) / 2,       // 40Hz
      tenBands[1],                           // 63Hz
      (tenBands[1] + tenBands[2]) / 2,       // 100Hz
      (tenBands[2] + tenBands[3]) / 2,       // 160Hz
      tenBands[3],                           // 250Hz
      (tenBands[3] + tenBands[4]) / 2,       // 400Hz
      (tenBands[4] + tenBands[5]) / 2,       // 630Hz
      tenBands[5],                           // 1kHz
      (tenBands[5] + tenBands[6]) / 2,       // 1.6kHz
      (tenBands[6] + tenBands[7]) / 2,       // 2.5kHz
      tenBands[7],                           // 4kHz
      (tenBands[7] + tenBands[8]) / 2,       // 6.3kHz
      (tenBands[8] + tenBands[9]) / 2,       // 10kHz
      tenBands[9],                           // 16kHz
    ];
  }

  @override
  Future<void> applyPreset(EqualizerPreset preset) async {
    _currentPreset = preset;
    _gains = List.from(preset.gains);
    _presetController.add(_currentPreset);
    await _applyGains();
    debugPrint('🎛️ EQ: Applied preset "${preset.name}"');
  }

  @override
  Future<void> reset() async {
    await applyPreset(BuiltInPresets.flat);
  }

  @override
  Future<void> dispose() async {
    _applyDebounceTimer?.cancel();
    _applyDebounceTimer = null;
    await setEnabled(false);
    await _enabledController.close();
    await _presetController.close();
  }
}

/// Unsupported platform stub (non-Linux platforms)
class _UnsupportedEqualizerService extends EqualizerService {
  @override
  bool get isAvailable => false;

  @override
  bool get isEnabled => false;

  @override
  Stream<bool> get enabledStream => Stream.value(false);

  @override
  EqualizerPreset get currentPreset => BuiltInPresets.flat;

  @override
  Stream<EqualizerPreset> get presetStream => Stream.value(BuiltInPresets.flat);

  @override
  List<double> get currentGains => List.filled(10, 0.0);

  @override
  Future<bool> initialize() async => false;

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Future<void> setBand(int bandIndex, double gainDb) async {}

  @override
  Future<void> setAllBands(List<double> gains) async {}

  @override
  Future<void> applyPreset(EqualizerPreset preset) async {}

  @override
  Future<void> reset() async {}

  @override
  Future<void> dispose() async {}
}
