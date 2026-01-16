import 'dart:async';

import 'package:flutter/material.dart';

import '../services/playback_state_store.dart';
import '../theme/nautune_theme.dart';

/// Manages the app's color theme/palette selection.
///
/// Responsibilities:
/// - Current palette selection
/// - Theme persistence
/// - Building ThemeData from selected palette
///
/// This provider is independent from other providers and only handles
/// visual theming concerns.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({
    required PlaybackStateStore playbackStateStore,
  }) : _playbackStateStore = playbackStateStore;

  final PlaybackStateStore _playbackStateStore;

  NautuneColorPalette _currentPalette = NautunePalettes.purpleOcean;
  bool _isInitialized = false;

  /// The currently selected color palette
  NautuneColorPalette get palette => _currentPalette;

  /// Whether the provider has been initialized
  bool get isInitialized => _isInitialized;

  /// Build ThemeData from the current palette
  ThemeData get themeData => _currentPalette.buildTheme();

  /// Initialize by loading persisted theme preference.
  ///
  /// This should be called once during app startup.
  Future<void> initialize() async {
    debugPrint('ThemeProvider: Initializing...');

    try {
      final storedState = await _playbackStateStore.load();
      if (storedState != null) {
        _currentPalette = NautunePalettes.getById(storedState.themePaletteId);
        debugPrint('ThemeProvider: Restored palette "${_currentPalette.name}"');
      }
    } catch (error) {
      debugPrint('ThemeProvider: Failed to load theme preference: $error');
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Set the current palette by ID
  void setPaletteById(String id) {
    final newPalette = NautunePalettes.getById(id);
    if (_currentPalette.id == newPalette.id) return;

    _currentPalette = newPalette;
    unawaited(_playbackStateStore.saveUiState(themePaletteId: id));
    debugPrint('ThemeProvider: Changed palette to "${_currentPalette.name}"');
    notifyListeners();
  }

  /// Set the current palette directly
  void setPalette(NautuneColorPalette palette) {
    if (_currentPalette.id == palette.id) return;

    _currentPalette = palette;
    unawaited(_playbackStateStore.saveUiState(themePaletteId: palette.id));
    debugPrint('ThemeProvider: Changed palette to "${_currentPalette.name}"');
    notifyListeners();
  }

  /// Get all available palettes
  List<NautuneColorPalette> get availablePalettes => NautunePalettes.all;
}
