import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../jellyfin/jellyfin_track.dart';
import '../../services/lyrics_service.dart';
import '../tui_metrics.dart';
import '../tui_theme.dart';
import '../widgets/tui_box.dart';

/// Lyrics display pane with synchronized scrolling.
/// Uses the same LyricsService as the GUI for consistent lyrics fetching.
class TuiLyricsPane extends StatefulWidget {
  const TuiLyricsPane({
    super.key,
    this.focused = false,
  });

  final bool focused;

  @override
  State<TuiLyricsPane> createState() => _TuiLyricsPaneState();
}

class _TuiLyricsPaneState extends State<TuiLyricsPane> {
  LyricsResult? _lyrics;
  bool _loading = false;
  String? _error;
  String? _currentTrackId;
  LyricsService? _lyricsService;


  @override
  Widget build(BuildContext context) {
    final appState = context.watch<NautuneAppState>();
    final audioService = appState.audioPlayerService;

    // Initialize lyrics service lazily
    _lyricsService ??= LyricsService(jellyfinService: appState.jellyfinService);

    return StreamBuilder<JellyfinTrack?>(
      stream: audioService.currentTrackStream,
      builder: (context, trackSnapshot) {
        final track = trackSnapshot.data;

        // Load lyrics when track changes (deferred to avoid setState during build)
        if (track?.id != _currentTrackId) {
          _currentTrackId = track?.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadLyrics(track);
            }
          });
        }

        return StreamBuilder<Duration>(
          stream: audioService.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;

            return TuiBox(
              title: _getLyricsTitle(),
              focused: widget.focused,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _buildContent(track, position),
              ),
            );
          },
        );
      },
    );
  }

  String _getLyricsTitle() {
    if (_lyrics != null && _lyrics!.isNotEmpty) {
      final sourceLabel = _getSourceLabel(_lyrics!.source);
      return 'Lyrics ($sourceLabel)';
    }
    return 'Lyrics';
  }

  String _getSourceLabel(String source) {
    switch (source) {
      case 'jellyfin':
        return 'Server';
      case 'lrclib':
        return 'LRCLIB';
      case 'lyricsovh':
        return 'lyrics.ovh';
      default:
        return source;
    }
  }

  Widget _buildContent(JellyfinTrack? track, Duration position) {
    if (track == null) {
      return Center(
        child: Text('No track playing', style: TuiTextStyles.dim),
      );
    }

    if (_loading) {
      return Center(
        child: Text('Loading lyrics...', style: TuiTextStyles.dim),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(_error!, style: TuiTextStyles.dim),
      );
    }

    if (_lyrics == null || _lyrics!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No lyrics available', style: TuiTextStyles.dim),
            const SizedBox(height: 8),
            Text(
              'Press L to refresh',
              style: TuiTextStyles.dim.copyWith(fontSize: 12),
            ),
          ],
        ),
      );
    }

    return _buildLyricsView(position);
  }

  Widget _buildLyricsView(Duration position) {
    final lines = _lyrics!.lines;

    // Convert position to ticks for comparison (Jellyfin ticks = 100ns units)
    // 1 microsecond = 10 ticks
    final currentTicks = position.inMicroseconds * 10;

    // Find current lyric line index
    int currentIndex = 0;
    for (int i = 0; i < lines.length; i++) {
      final lineTicks = lines[i].startTicks;
      if (lineTicks != null && lineTicks <= currentTicks) {
        currentIndex = i;
      } else if (lineTicks != null) {
        break;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final lineHeight = TuiMetrics.charHeight;
        final visibleLines = (constraints.maxHeight / lineHeight).floor();
        final centerLine = visibleLines ~/ 2;

        // Calculate scroll offset to center current line
        int startIndex = (currentIndex - centerLine).clamp(0, lines.length - 1);
        int endIndex = (startIndex + visibleLines).clamp(0, lines.length);

        // Adjust if we're near the end
        if (endIndex - startIndex < visibleLines && lines.length >= visibleLines) {
          startIndex = (lines.length - visibleLines).clamp(0, lines.length - 1);
          endIndex = lines.length;
        }

        return ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = startIndex; i < endIndex; i++)
                SizedBox(
                  height: lineHeight,
                  child: _buildLyricLine(lines[i], i == currentIndex),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLyricLine(LyricLine line, bool isCurrent) {
    final style = isCurrent
        ? TuiTextStyles.normal.copyWith(
            color: TuiColors.primary,
            fontWeight: FontWeight.bold,
          )
        : TuiTextStyles.dim;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        line.text.isEmpty ? '...' : line.text,
        style: style,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _loadLyrics(JellyfinTrack? track) async {
    if (track == null) {
      setState(() {
        _lyrics = null;
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _lyrics = null;
    });

    try {
      final result = await _lyricsService!.getLyrics(track);
      if (mounted) {
        setState(() {
          _lyrics = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load lyrics';
          _loading = false;
        });
      }
    }
  }
}
