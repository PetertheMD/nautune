import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/connectivity_service.dart';

/// Manages network connectivity state.
///
/// Responsibilities:
/// - Monitor network availability
/// - Provide connectivity status to the app
/// - Emit events when connectivity changes
/// - Debounce rapid connectivity changes for smooth UX
///
/// This is a thin wrapper around ConnectivityService that makes it
/// compatible with the Provider pattern.
class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider({
    required ConnectivityService connectivityService,
    this.debounceDelay = const Duration(seconds: 2),
  }) : _connectivityService = connectivityService;

  final ConnectivityService _connectivityService;
  final Duration debounceDelay;
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _debounceTimer;
  bool _networkAvailable = true;
  bool _pendingNetworkState = true;
  bool _initialized = false;

  bool get networkAvailable => _networkAvailable;
  bool get isInitialized => _initialized;
  
  /// Returns true if the network state recently changed (within debounce window).
  /// Useful for showing transition indicators in UI.
  bool get isTransitioning => _debounceTimer?.isActive ?? false;

  /// Initialize connectivity monitoring.
  ///
  /// This should be called once during app startup.
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('ConnectivityProvider already initialized');
      return;
    }

    debugPrint('ConnectivityProvider: Initializing...');

    try {
      final isOnline = await _connectivityService.hasNetworkConnection();
      _networkAvailable = isOnline;
      _pendingNetworkState = isOnline;
      debugPrint('ConnectivityProvider: Initial network status: $isOnline');
    } catch (error) {
      debugPrint('ConnectivityProvider: Connectivity probe failed: $error');
      _networkAvailable = false;
      _pendingNetworkState = false;
    }

    _connectivitySubscription = _connectivityService.onStatusChange.listen(
      _handleConnectivityChange,
    );

    _initialized = true;
    notifyListeners();
  }

  void _handleConnectivityChange(bool isOnline) {
    // Track the pending state for debouncing
    _pendingNetworkState = isOnline;
    
    // Cancel any existing debounce timer
    _debounceTimer?.cancel();
    
    // If going offline, apply immediately (user needs to know right away)
    if (!isOnline && _networkAvailable) {
      _applyNetworkState(isOnline);
      return;
    }
    
    // If going online, debounce to avoid flicker from unstable connections
    _debounceTimer = Timer(debounceDelay, () {
      if (_pendingNetworkState != _networkAvailable) {
        _applyNetworkState(_pendingNetworkState);
      }
    });
  }
  
  void _applyNetworkState(bool isOnline) {
    final wasOnline = _networkAvailable;
    _networkAvailable = isOnline;

    if (wasOnline != isOnline) {
      debugPrint('ConnectivityProvider: Network status changed to: $isOnline');
      notifyListeners();
    }
  }
  
  /// Force a connectivity check and update state.
  /// Useful for manual refresh or when returning from background.
  Future<void> checkConnectivity() async {
    try {
      final isOnline = await _connectivityService.hasNetworkConnection();
      if (isOnline != _networkAvailable) {
        _applyNetworkState(isOnline);
      }
    } catch (error) {
      debugPrint('ConnectivityProvider: Manual check failed: $error');
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
