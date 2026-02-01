import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' show max;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/chart_data.dart';
import '../models/download_item.dart';
import '../services/chart_cache_service.dart';
import '../services/chart_generator_service.dart';
import '../services/listening_analytics_service.dart';
import '../widgets/jellyfin_image.dart';

/// Frets on Fire - Guitar Hero style rhythm game easter egg.
/// Search "fire" in Library to discover this screen.
class FretsOnFireScreen extends StatefulWidget {
  const FretsOnFireScreen({super.key});

  @override
  State<FretsOnFireScreen> createState() => _FretsOnFireScreenState();
}

class _FretsOnFireScreenState extends State<FretsOnFireScreen>
    with TickerProviderStateMixin {
  // Services
  final _chartGenerator = ChartGeneratorService.instance;
  final _chartCache = ChartCacheService.instance;
  NautuneAppState? _appState;

  // Game state
  GameState _gameState = GameState.selectTrack;
  ChartData? _chart;
  String? _selectedTrackPath;

  // Audio player for game (separate from main player)
  final AudioPlayer _gamePlayer = AudioPlayer();
  Duration _position = Duration.zero;

  // Gameplay
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _multiplier = 1;
  int _perfectHits = 0;
  int _goodHits = 0;
  int _missedNotes = 0;
  int _nextNoteIndex = 0;

  // Animation
  late AnimationController _noteController;

  // Keyboard focus
  final FocusNode _focusNode = FocusNode();

  // Timing windows - calculated from BPM like original Frets on Fire
  // Original formula: 60000 / BPM / 3.5 for hit window
  int get _hitWindow => _chart != null ? (60000 / _chart!.bpm / 3.5).round() : 143;
  int get _perfectWindow => (_hitWindow * 0.4).round(); // Tighter window for perfect
  static const int _noteLeadTime = 2000; // Notes visible 2 seconds before hit

  // Lane states for visual feedback (5 frets like original)
  final List<bool> _lanePressed = [false, false, false, false, false];
  final List<DateTime?> _laneHitTime = [null, null, null, null, null];

  @override
  void initState() {
    super.initState();
    _chartCache.initialize();

    // Mark easter egg as discovered for milestone badge
    ListeningAnalyticsService().markFretsOnFireDiscovered();

    _noteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60fps
    )..addListener(_onFrame);

    _gamePlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
      }
    });

    _gamePlayer.onDurationChanged.listen((dur) {
      // Duration tracked for reference, not used in UI currently
    });

    _gamePlayer.onPlayerComplete.listen((_) {
      if (mounted && _gameState == GameState.playing) {
        _endGame();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState ??= context.read<NautuneAppState>();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _gamePlayer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFrame() {
    if (_gameState != GameState.playing || _chart == null) return;

    final currentMs = _position.inMilliseconds;

    // Check for missed notes (past the hit window)
    while (_nextNoteIndex < _chart!.notes.length) {
      final note = _chart!.notes[_nextNoteIndex];
      if (note.timestampMs < currentMs - _hitWindow) {
        // Missed this note
        _missNote();
        _nextNoteIndex++;
      } else {
        break;
      }
    }

    if (mounted) setState(() {});
  }

  void _missNote() {
    _missedNotes++;
    _combo = 0;
    _multiplier = 1;
  }

  void _hitNote(int lane, bool isPerfect) {
    // Scoring like original Frets on Fire: 50 points per note * multiplier
    if (isPerfect) {
      _perfectHits++;
      _score += 50 * _multiplier;
    } else {
      _goodHits++;
      _score += 50 * _multiplier;
    }

    _combo++;
    _maxCombo = max(_maxCombo, _combo);

    // Multiplier milestones like original: 10→2x, 20→3x, 30→4x (max 4x)
    if (_combo == 10) {
      _multiplier = 2;
    } else if (_combo == 20) {
      _multiplier = 3;
    } else if (_combo == 30) {
      _multiplier = 4;
    }

    _laneHitTime[lane] = DateTime.now();
  }

  void _onLaneTap(int lane) {
    if (_gameState != GameState.playing || _chart == null) return;
    if (lane < 0 || lane >= 5) return; // Validate lane index

    _lanePressed[lane] = true;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _lanePressed[lane] = false);
    });

    final currentMs = _position.inMilliseconds;

    // Find a note in this lane that's within the hit window
    for (int i = _nextNoteIndex; i < _chart!.notes.length; i++) {
      final note = _chart!.notes[i];
      if (note.lane != lane) continue;

      final diff = (note.timestampMs - currentMs).abs();

      if (diff <= _perfectWindow) {
        _hitNote(lane, true);
        _nextNoteIndex = i + 1;
        setState(() {});
        return;
      } else if (diff <= _hitWindow) {
        _hitNote(lane, false);
        _nextNoteIndex = i + 1;
        setState(() {});
        return;
      }

      // Notes are sorted, so if this note is too far in the future, stop looking
      if (note.timestampMs > currentMs + _hitWindow) break;
    }
  }

  Future<void> _selectTrack() async {
    // Get downloaded tracks from download service
    final downloads = _appState?.downloadService.completedDownloads ?? [];

    if (downloads.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No downloaded tracks available')),
        );
      }
      return;
    }

    // Show track selection dialog
    final selected = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _TrackSelectionDialog(downloads: downloads),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedTrackPath = selected['path'];
        _gameState = GameState.analyzing;
      });
      _analyzeTrack(
        selected['path']!,
        selected['id']!,
        selected['name']!,
        selected['artist']!,
        int.parse(selected['duration']!),
      );
    }
  }

  Future<void> _analyzeTrack(
    String path,
    String trackId,
    String trackName,
    String artistName,
    int durationMs,
  ) async {
    // Check cache first
    final cached = _chartCache.getChart(trackId);
    if (cached != null) {
      setState(() {
        _chart = cached;
        _gameState = GameState.ready;
      });
      return;
    }

    // Generate new chart
    final chart = await _chartGenerator.generateChart(
      audioPath: path,
      trackId: trackId,
      trackName: trackName,
      artistName: artistName,
      durationMs: durationMs,
    );

    if (chart != null && mounted) {
      await _chartCache.saveChart(chart);
      setState(() {
        _chart = chart;
        _gameState = GameState.ready;
      });
    } else if (mounted) {
      setState(() => _gameState = GameState.selectTrack);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to analyze track')),
      );
    }
  }

  Future<void> _startGame() async {
    if (_chart == null || _selectedTrackPath == null) return;

    // Reset game state
    _score = 0;
    _combo = 0;
    _maxCombo = 0;
    _multiplier = 1;
    _perfectHits = 0;
    _goodHits = 0;
    _missedNotes = 0;
    _nextNoteIndex = 0;

    // Start audio
    await _gamePlayer.play(DeviceFileSource(_selectedTrackPath!));

    setState(() => _gameState = GameState.playing);
    _noteController.repeat();
    _focusNode.requestFocus();
  }

  void _pauseGame() {
    _gamePlayer.pause();
    _noteController.stop();
    setState(() => _gameState = GameState.paused);
  }

  void _resumeGame() {
    _gamePlayer.resume();
    _noteController.repeat();
    setState(() => _gameState = GameState.playing);
    _focusNode.requestFocus();
  }

  void _endGame() {
    _noteController.stop();
    _gamePlayer.stop();

    // Check for remaining notes as missed
    while (_nextNoteIndex < (_chart?.notes.length ?? 0)) {
      _missedNotes++;
      _nextNoteIndex++;
    }

    // Update high score
    if (_chart != null && _score > _chart!.highScore) {
      _chartCache.updateScore(_chart!.trackId, _score, _multiplier);
    }

    setState(() => _gameState = GameState.ended);
  }

  void _restartGame() {
    setState(() => _gameState = GameState.ready);
  }

  void _backToSelect() {
    _gamePlayer.stop();
    setState(() {
      _gameState = GameState.selectTrack;
      _chart = null;
      _selectedTrackPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _gameState == GameState.playing
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              title: Text(
                'FRETS ON FIRE',
                style: GoogleFonts.raleway(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  fontSize: 20,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: _buildBody(theme),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_gameState != GameState.playing) return;

    // Map keys to 5 lanes: 1-5 or F1-F5
    int? lane;
    if (event.logicalKey == LogicalKeyboardKey.digit1 ||
        event.logicalKey == LogicalKeyboardKey.f1) {
      lane = 0;
    } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
        event.logicalKey == LogicalKeyboardKey.f2) {
      lane = 1;
    } else if (event.logicalKey == LogicalKeyboardKey.digit3 ||
        event.logicalKey == LogicalKeyboardKey.f3) {
      lane = 2;
    } else if (event.logicalKey == LogicalKeyboardKey.digit4 ||
        event.logicalKey == LogicalKeyboardKey.f4) {
      lane = 3;
    } else if (event.logicalKey == LogicalKeyboardKey.digit5 ||
        event.logicalKey == LogicalKeyboardKey.f5) {
      lane = 4;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _pauseGame();
      return;
    }

    if (lane != null) {
      _onLaneTap(lane);
    }
  }

  Widget _buildBody(ThemeData theme) {
    switch (_gameState) {
      case GameState.selectTrack:
        return _buildTrackSelect(theme);
      case GameState.analyzing:
        return _buildAnalyzing(theme);
      case GameState.ready:
        return _buildReady(theme);
      case GameState.playing:
        return _buildPlaying(theme);
      case GameState.paused:
        return _buildPaused(theme);
      case GameState.ended:
        return _buildEnded(theme);
    }
  }

  Widget _buildTrackSelect(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_fire_department,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Select a track to play',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only downloaded tracks are available',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _selectTrack,
              icon: const Icon(Icons.library_music),
              label: const Text('CHOOSE TRACK'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzing(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Analyzing track...',
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<double>(
            valueListenable: _chartGenerator.progress,
            builder: (context, progress, _) {
              return Text(
                '${(progress * 100).toInt()}%',
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white54),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReady(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _chart?.trackName ?? 'Unknown Track',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _chart?.artistName ?? 'Unknown Artist',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _InfoChip(
                  icon: Icons.music_note,
                  label: '${_chart?.notes.length ?? 0} notes',
                ),
                const SizedBox(width: 16),
                _InfoChip(
                  icon: Icons.timer,
                  label: _chart?.formattedDuration ?? '0:00',
                ),
                const SizedBox(width: 16),
                _InfoChip(
                  icon: Icons.speed,
                  label: _chart?.formattedBpm ?? '-- BPM',
                ),
              ],
            ),
            if (_chart != null && _chart!.highScore > 0) ...[
              const SizedBox(height: 16),
              Text(
                'High Score: ${_chart!.formattedHighScore}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _backToSelect,
                  child: const Text('BACK'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _startGame,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('START'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              Platform.isLinux || Platform.isMacOS || Platform.isWindows
                  ? 'Press 1-5 or F1-F5 to play'
                  : 'Tap the 5 lanes to hit notes',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaying(ThemeData theme) {
    return Stack(
      children: [
        // Note highway
        _NoteHighway(
          chart: _chart!,
          currentTimeMs: _position.inMilliseconds,
          leadTimeMs: _noteLeadTime,
          lanePressed: _lanePressed,
          laneHitTime: _laneHitTime,
          primaryColor: theme.colorScheme.primary,
          onLaneTap: _onLaneTap,
        ),
        // Score display with Nautune font
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SCORE',
                    style: GoogleFonts.raleway(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _score.toString(),
                    style: GoogleFonts.raleway(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'COMBO',
                    style: GoogleFonts.raleway(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _combo.toString(),
                    style: GoogleFonts.raleway(
                      color: theme.colorScheme.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_multiplier}x',
                  style: GoogleFonts.raleway(
                    color: theme.colorScheme.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Pause button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.pause, color: Colors.white54),
            onPressed: _pauseGame,
          ),
        ),
      ],
    );
  }

  Widget _buildPaused(ThemeData theme) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'PAUSED',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _resumeGame,
              icon: const Icon(Icons.play_arrow),
              label: const Text('RESUME'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _endGame,
              child: const Text('QUIT'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnded(ThemeData theme) {
    final totalNotes = _chart?.notes.length ?? 0;
    final accuracy = totalNotes > 0
        ? ((_perfectHits + _goodHits) / totalNotes * 100)
        : 0.0;

    String grade;
    if (accuracy >= 95) {
      grade = 'S';
    } else if (accuracy >= 90) {
      grade = 'A';
    } else if (accuracy >= 80) {
      grade = 'B';
    } else if (accuracy >= 70) {
      grade = 'C';
    } else if (accuracy >= 60) {
      grade = 'D';
    } else {
      grade = 'F';
    }

    final isNewHighScore = _chart != null && _score > _chart!.highScore;

    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isNewHighScore) ...[
                Text(
                  'NEW HIGH SCORE!',
                  style: GoogleFonts.raleway(
                    color: theme.colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                grade,
                style: GoogleFonts.pacifico(
                  color: theme.colorScheme.primary,
                  fontSize: 80,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _score.toString(),
                style: GoogleFonts.raleway(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatColumn(label: 'Perfect', value: _perfectHits.toString()),
                  const SizedBox(width: 32),
                  _StatColumn(label: 'Good', value: _goodHits.toString()),
                  const SizedBox(width: 32),
                  _StatColumn(label: 'Missed', value: _missedNotes.toString()),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatColumn(label: 'Max Combo', value: _maxCombo.toString()),
                  const SizedBox(width: 32),
                  _StatColumn(label: 'Accuracy', value: '${accuracy.toStringAsFixed(1)}%'),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _backToSelect,
                    child: const Text('BACK'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _restartGame,
                    icon: const Icon(Icons.replay),
                    label: const Text('PLAY AGAIN'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum GameState {
  selectTrack,
  analyzing,
  ready,
  playing,
  paused,
  ended,
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.raleway(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.raleway(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Note highway widget - renders falling notes and hit zones
class _NoteHighway extends StatelessWidget {
  final ChartData chart;
  final int currentTimeMs;
  final int leadTimeMs;
  final List<bool> lanePressed;
  final List<DateTime?> laneHitTime;
  final Color primaryColor;
  final Function(int) onLaneTap;

  const _NoteHighway({
    required this.chart,
    required this.currentTimeMs,
    required this.leadTimeMs,
    required this.lanePressed,
    required this.laneHitTime,
    required this.primaryColor,
    required this.onLaneTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth = constraints.maxWidth / 5; // 5 lanes
        final hitLineY = constraints.maxHeight - 120;

        // Get visible notes
        final visibleNotes = <ChartNote>[];
        for (final note in chart.notes) {
          if (note.timestampMs >= currentTimeMs - 100 &&
              note.timestampMs <= currentTimeMs + leadTimeMs) {
            visibleNotes.add(note);
          }
          if (note.timestampMs > currentTimeMs + leadTimeMs) break;
        }

        return GestureDetector(
          onTapDown: (details) {
            final lane = (details.localPosition.dx / laneWidth).floor().clamp(0, 4);
            onLaneTap(lane);
          },
          child: CustomPaint(
            painter: _NoteHighwayPainter(
              notes: visibleNotes,
              currentTimeMs: currentTimeMs,
              leadTimeMs: leadTimeMs,
              hitLineY: hitLineY,
              laneWidth: laneWidth,
              lanePressed: lanePressed,
              laneHitTime: laneHitTime,
              primaryColor: primaryColor,
            ),
            size: Size(constraints.maxWidth, constraints.maxHeight),
          ),
        );
      },
    );
  }
}

class _NoteHighwayPainter extends CustomPainter {
  final List<ChartNote> notes;
  final int currentTimeMs;
  final int leadTimeMs;
  final double hitLineY;
  final double laneWidth;
  final List<bool> lanePressed;
  final List<DateTime?> laneHitTime;
  final Color primaryColor;

  _NoteHighwayPainter({
    required this.notes,
    required this.currentTimeMs,
    required this.leadTimeMs,
    required this.hitLineY,
    required this.laneWidth,
    required this.lanePressed,
    required this.laneHitTime,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Generate lane colors from theme primary using hue shifts
    // Creates a rainbow spread around the primary color
    final baseHsl = HSLColor.fromColor(primaryColor);
    final laneColors = [
      baseHsl.withHue((baseHsl.hue - 60) % 360).withSaturation(0.9).withLightness(0.5).toColor(),  // Lane 0
      baseHsl.withHue((baseHsl.hue - 30) % 360).withSaturation(0.9).withLightness(0.5).toColor(),  // Lane 1
      baseHsl.withSaturation(0.9).withLightness(0.55).toColor(),                                    // Lane 2 - Primary
      baseHsl.withHue((baseHsl.hue + 30) % 360).withSaturation(0.9).withLightness(0.5).toColor(),  // Lane 3
      baseHsl.withHue((baseHsl.hue + 60) % 360).withSaturation(0.9).withLightness(0.5).toColor(),  // Lane 4
    ];

    // Draw lane dividers
    final lanePaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;

    for (int i = 1; i < 5; i++) {
      canvas.drawLine(
        Offset(i * laneWidth, 0),
        Offset(i * laneWidth, size.height),
        lanePaint,
      );
    }

    // Draw hit line
    final hitLinePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.8)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(0, hitLineY),
      Offset(size.width, hitLineY),
      hitLinePaint,
    );

    // Draw hit zones for 5 frets
    for (int lane = 0; lane < 5; lane++) {
      final isPressed = lanePressed[lane];
      final hitTime = laneHitTime[lane];
      final isRecentHit = hitTime != null &&
          DateTime.now().difference(hitTime).inMilliseconds < 150;

      final zoneRect = Rect.fromLTWH(
        lane * laneWidth + 2,
        hitLineY - 20,
        laneWidth - 4,
        40,
      );

      final zonePaint = Paint()
        ..color = isPressed || isRecentHit
            ? laneColors[lane].withValues(alpha: 0.5)
            : laneColors[lane].withValues(alpha: 0.2);

      canvas.drawRRect(
        RRect.fromRectAndRadius(zoneRect, const Radius.circular(8)),
        zonePaint,
      );

      // Hit flash effect
      if (isRecentHit) {
        final flashPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
        canvas.drawCircle(
          Offset(lane * laneWidth + laneWidth / 2, hitLineY),
          20,
          flashPaint,
        );
      }
    }

    // Draw notes
    final notePaint = Paint()..style = PaintingStyle.fill;
    final noteGlowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (final note in notes) {
      // Clamp lane to valid range (0-4)
      final lane = note.lane.clamp(0, 4);
      final progress = (note.timestampMs - currentTimeMs) / leadTimeMs;
      final noteY = hitLineY - (progress * hitLineY);
      final noteX = lane * laneWidth + laneWidth / 2;

      final color = laneColors[lane];

      // Glow
      noteGlowPaint.color = color.withValues(alpha: 0.4);
      canvas.drawCircle(Offset(noteX, noteY), 14, noteGlowPaint);

      // Note (smaller for 5 lanes)
      notePaint.color = color;
      canvas.drawCircle(Offset(noteX, noteY), 10, notePaint);

      // Inner highlight
      notePaint.color = Colors.white.withValues(alpha: 0.4);
      canvas.drawCircle(Offset(noteX - 3, noteY - 3), 3, notePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoteHighwayPainter old) => true;
}

/// Track selection dialog with album art
class _TrackSelectionDialog extends StatelessWidget {
  final List<DownloadItem> downloads;

  const _TrackSelectionDialog({required this.downloads});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Row(
        children: [
          Icon(Icons.local_fire_department, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          Text('Select Track', style: TextStyle(color: theme.colorScheme.onSurface)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: downloads.length,
          itemBuilder: (context, index) {
            final item = downloads[index];
            final track = item.track;

            // Get album art info
            final hasAlbumArt = track.albumId != null && track.albumPrimaryImageTag != null;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(context, {
                      'path': item.localPath,
                      'id': track.id,
                      'name': track.name,
                      'artist': track.artists.isNotEmpty ? track.artists.first : 'Unknown Artist',
                      'duration': track.runTimeTicks != null
                          ? (track.runTimeTicks! ~/ 10000).toString()
                          : '180000',
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        // Album art
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: hasAlbumArt
                                ? JellyfinImage(
                                    itemId: track.albumId!,
                                    imageTag: track.albumPrimaryImageTag,
                                    trackId: track.id,
                                    width: 56,
                                    height: 56,
                                    errorBuilder: (context, url, error) => Container(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      child: Icon(
                                        Icons.album,
                                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                        size: 28,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.album,
                                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                      size: 28,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Track info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                track.name,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.artists.isNotEmpty ? track.artists.first : 'Unknown Artist',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (track.album != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  track.album!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Play icon
                        Icon(
                          Icons.play_circle_outline,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
      ],
    );
  }
}
