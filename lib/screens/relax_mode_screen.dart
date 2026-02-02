import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../services/haptic_service.dart';
import '../services/listening_analytics_service.dart';

/// Ambient sound mixer screen with vertical sliders for Rain, Thunder, Campfire, Waves, and Loon.
class RelaxModeScreen extends StatefulWidget {
  const RelaxModeScreen({super.key});

  @override
  State<RelaxModeScreen> createState() => _RelaxModeScreenState();
}

class _RelaxModeScreenState extends State<RelaxModeScreen> {
  // Audio players for each ambient sound
  final AudioPlayer _rainPlayer = AudioPlayer();
  final AudioPlayer _thunderPlayer = AudioPlayer();
  final AudioPlayer _campfirePlayer = AudioPlayer();
  final AudioPlayer _wavePlayer = AudioPlayer();
  final AudioPlayer _loonPlayer = AudioPlayer();

  // Volume levels (0.0 to 1.0)
  double _rainVolume = 0.0;
  double _thunderVolume = 0.0;
  double _campfireVolume = 0.0;
  double _waveVolume = 0.0;
  double _loonVolume = 0.0;

  // Track initialization state
  bool _initialized = false;

  // Analytics tracking
  Timer? _usageTimer;
  int _activeListeningMs = 0; // Time when at least one sound is playing
  int _rainUsageMs = 0;
  int _thunderUsageMs = 0;
  int _campfireUsageMs = 0;
  int _waveUsageMs = 0;
  int _loonUsageMs = 0;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _initAnalytics();
  }

  void _initAnalytics() {
    // Mark Relax Mode as discovered for the milestone
    final analytics = ListeningAnalyticsService();
    if (analytics.isInitialized) {
      analytics.markRelaxModeDiscovered();
    }
  }

  void _startTracking() {
    if (_usageTimer != null) return;

    // Track slider usage every second
    // Only count time when at least one sound is actively playing
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final isAnySoundActive = _rainVolume > 0 || _thunderVolume > 0 ||
          _campfireVolume > 0 || _waveVolume > 0 || _loonVolume > 0;

      // Only count active listening time (when at least one sound is on)
      if (isAnySoundActive) {
        _activeListeningMs += 1000;
      }

      // Track individual sound usage
      if (_rainVolume > 0) {
        _rainUsageMs += 1000;
      }
      if (_thunderVolume > 0) {
        _thunderUsageMs += 1000;
      }
      if (_campfireVolume > 0) {
        _campfireUsageMs += 1000;
      }
      if (_waveVolume > 0) {
        _waveUsageMs += 1000;
      }
      if (_loonVolume > 0) {
        _loonUsageMs += 1000;
      }
    });
  }

  Future<void> _initAudio() async {
    // Set release mode to loop for continuous ambient playback
    await _rainPlayer.setReleaseMode(ReleaseMode.loop);
    await _thunderPlayer.setReleaseMode(ReleaseMode.loop);
    await _campfirePlayer.setReleaseMode(ReleaseMode.loop);
    await _wavePlayer.setReleaseMode(ReleaseMode.loop);
    await _loonPlayer.setReleaseMode(ReleaseMode.loop);

    // Set initial volume to 0
    await _rainPlayer.setVolume(0.0);
    await _thunderPlayer.setVolume(0.0);
    await _campfirePlayer.setVolume(0.0);
    await _wavePlayer.setVolume(0.0);
    await _loonPlayer.setVolume(0.0);

    // Load and start playing (at volume 0)
    await _rainPlayer.setSource(AssetSource('relax/rain.mp3'));
    await _thunderPlayer.setSource(AssetSource('relax/thunder.mp3'));
    await _campfirePlayer.setSource(AssetSource('relax/campfire.mp3'));
    await _wavePlayer.setSource(AssetSource('relax/wave.mp3'));
    await _loonPlayer.setSource(AssetSource('relax/loon.mp3'));

    if (mounted) {
      setState(() => _initialized = true);
      // Start tracking only after audio is ready
      _startTracking();
    }
  }

  @override
  void dispose() {
    // Stop tracking
    _usageTimer?.cancel();

    // Record session to analytics only if user actually listened (> 5 seconds of active sound)
    final analytics = ListeningAnalyticsService();
    if (analytics.isInitialized && _activeListeningMs > 5000) {
      analytics.recordRelaxModeSession(
        sessionDuration: Duration(milliseconds: _activeListeningMs),
        rainUsage: Duration(milliseconds: _rainUsageMs),
        thunderUsage: Duration(milliseconds: _thunderUsageMs),
        campfireUsage: Duration(milliseconds: _campfireUsageMs),
        waveUsage: Duration(milliseconds: _waveUsageMs),
        loonUsage: Duration(milliseconds: _loonUsageMs),
      );
    }

    // Dispose audio players
    _rainPlayer.dispose();
    _thunderPlayer.dispose();
    _campfirePlayer.dispose();
    _wavePlayer.dispose();
    _loonPlayer.dispose();
    super.dispose();
  }

  void _onRainVolumeChanged(double value) {
    setState(() => _rainVolume = value);
    _rainPlayer.setVolume(value);
    if (value > 0 && _rainPlayer.state != PlayerState.playing) {
      _rainPlayer.resume();
    }
    HapticService.selectionClick();
  }

  void _onThunderVolumeChanged(double value) {
    setState(() => _thunderVolume = value);
    _thunderPlayer.setVolume(value);
    if (value > 0 && _thunderPlayer.state != PlayerState.playing) {
      _thunderPlayer.resume();
    }
    HapticService.selectionClick();
  }

  void _onCampfireVolumeChanged(double value) {
    setState(() => _campfireVolume = value);
    _campfirePlayer.setVolume(value);
    if (value > 0 && _campfirePlayer.state != PlayerState.playing) {
      _campfirePlayer.resume();
    }
    HapticService.selectionClick();
  }

  void _onWaveVolumeChanged(double value) {
    setState(() => _waveVolume = value);
    _wavePlayer.setVolume(value);
    if (value > 0 && _wavePlayer.state != PlayerState.playing) {
      _wavePlayer.resume();
    }
    HapticService.selectionClick();
  }

  void _onLoonVolumeChanged(double value) {
    setState(() => _loonVolume = value);
    _loonPlayer.setVolume(value);
    if (value > 0 && _loonPlayer.state != PlayerState.playing) {
      _loonPlayer.resume();
    }
    HapticService.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.waves),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: _initialized
            ? _buildSliders(theme)
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildSliders(ThemeData theme) {
    // Use responsive padding for narrow screens (5 sliders need more space)
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 400 ? 16.0 : 32.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAmbientSlider(
            theme: theme,
            icon: Icons.water_drop,
            color: theme.colorScheme.primary,
            value: _rainVolume,
            onChanged: _onRainVolumeChanged,
          ),
          _buildAmbientSlider(
            theme: theme,
            icon: Icons.thunderstorm,
            color: theme.colorScheme.secondary,
            value: _thunderVolume,
            onChanged: _onThunderVolumeChanged,
          ),
          _buildAmbientSlider(
            theme: theme,
            icon: Icons.local_fire_department,
            color: theme.colorScheme.tertiary,
            value: _campfireVolume,
            onChanged: _onCampfireVolumeChanged,
          ),
          _buildAmbientSlider(
            theme: theme,
            icon: Icons.waves,
            color: Colors.cyan,
            value: _waveVolume,
            onChanged: _onWaveVolumeChanged,
          ),
          _buildAmbientSlider(
            theme: theme,
            icon: Icons.nights_stay,
            color: Colors.indigo,
            value: _loonVolume,
            onChanged: _onLoonVolumeChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientSlider({
    required ThemeData theme,
    required IconData icon,
    required Color color,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    // Responsive sizing for narrow screens
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth < 400 ? 24.0 : 32.0;

    return Expanded(
      child: Column(
        children: [
          // Icon
          Icon(
            icon,
            color: value > 0 ? color : theme.colorScheme.onSurfaceVariant,
            size: iconSize,
          ),
          const SizedBox(height: 12),
          // Vertical slider
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: screenWidth < 400 ? 4 : 6,
                  activeTrackColor: color,
                  inactiveTrackColor: color.withValues(alpha: 0.15),
                  thumbColor: color,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: screenWidth < 400 ? 6 : 8,
                  ),
                  overlayShape: RoundSliderOverlayShape(
                    overlayRadius: screenWidth < 400 ? 12 : 16,
                  ),
                  overlayColor: color.withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: value,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
