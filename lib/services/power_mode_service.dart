import 'dart:async';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

/// Service for detecting iOS Low Power Mode to disable battery-intensive features.
/// On non-iOS platforms, this service does nothing.
class PowerModeService {
  static final PowerModeService _instance = PowerModeService._();
  static PowerModeService get instance => _instance;
  PowerModeService._();

  final Battery _battery = Battery();
  final _lowPowerModeController = StreamController<bool>.broadcast();
  StreamSubscription? _batterySub;
  bool _isLowPowerMode = false;
  bool _initialized = false;

  /// Stream of Low Power Mode state changes
  Stream<bool> get lowPowerModeStream => _lowPowerModeController.stream;

  /// Current Low Power Mode state
  bool get isLowPowerMode => _isLowPowerMode;

  /// Initialize the service (only does work on iOS)
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Low Power Mode detection only works on iOS via battery_plus
    if (!Platform.isIOS) {
      debugPrint('🔋 PowerModeService: Not iOS, skipping initialization');
      return;
    }

    try {
      // Check initial state
      _isLowPowerMode = await _battery.isInBatterySaveMode;
      _lowPowerModeController.add(_isLowPowerMode);
      debugPrint('🔋 PowerModeService: Initial Low Power Mode = $_isLowPowerMode');

      // Listen for battery state changes (triggers re-check of Low Power Mode)
      _batterySub = _battery.onBatteryStateChanged.listen((_) async {
        final newState = await _battery.isInBatterySaveMode;
        if (newState != _isLowPowerMode) {
          _isLowPowerMode = newState;
          _lowPowerModeController.add(newState);
          debugPrint('🔋 Low Power Mode: ${newState ? "ON" : "OFF"}');
        }
      });
    } catch (e) {
      debugPrint('🔋 PowerModeService: Failed to initialize: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    _batterySub?.cancel();
    _lowPowerModeController.close();
  }
}
