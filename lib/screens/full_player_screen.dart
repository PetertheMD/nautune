import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../jellyfin/jellyfin_track.dart';
import '../services/audio_player_service.dart';

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> with SingleTickerProviderStateMixin {
  StreamSubscription? _trackSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _playingSub;
  late TabController _tabController;
  Map<String, dynamic>? _lyricsData;
  bool _loadingLyrics = false;
  late AudioPlayerService _audioService;
  late NautuneAppState _appState;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get services from Provider
    _appState = Provider.of<NautuneAppState>(context, listen: false);
    _audioService = _appState.audioService;

    // Set up stream listeners only once
    if (_trackSub == null) {
      _trackSub = _audioService.currentTrackStream.listen((track) {
        if (mounted) {
          setState(() {});
          if (track != null) {
            _fetchLyrics(track);
          }
        }
      });
      _positionSub = _audioService.positionStream.listen((_) {
        if (mounted) setState(() {});
      });
      _playingSub = _audioService.playingStream.listen((_) {
        if (mounted) setState(() {});
      });

      // Fetch lyrics for initial track
      final currentTrack = _audioService.currentTrack;
      if (currentTrack != null) {
        _fetchLyrics(currentTrack);
      }
    }
  }

  Future<void> _fetchLyrics(JellyfinTrack track) async {
    setState(() {
      _loadingLyrics = true;
      _lyricsData = null;
    });

    try {
      final jellyfinService = _appState.jellyfinService;
      final lyrics = await jellyfinService.getLyrics(track.id);
      if (mounted) {
        setState(() {
          _lyricsData = lyrics;
          _loadingLyrics = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Failed to fetch lyrics: $e');
      if (mounted) {
        setState(() {
          _loadingLyrics = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _trackSub?.cancel();
    _positionSub?.cancel();
    _playingSub?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  double _sliderValue(Duration position, Duration duration) {
    if (duration.inMilliseconds > 0) {
      final max = duration.inMilliseconds.toDouble();
      final raw = position.inMilliseconds.toDouble();
      if (raw < 0) return 0.0;
      if (raw > max) return max;
      return raw;
    }
    return 0.0;
  }

  double _sliderMax(Duration position, Duration duration) {
    if (duration.inMilliseconds > 0) {
      return duration.inMilliseconds.toDouble();
    }
    final pos = position.inMilliseconds.toDouble();
    if (pos <= 0) {
      return 1.0;
    }
    return pos;
  }

  void _seekFromGesture(double dx, double maxWidth, Duration duration) {
    if (duration.inMilliseconds > 0 && maxWidth > 0) {
      final ratio = (dx / maxWidth).clamp(0.0, 1.0);
      final newPosition = Duration(
        milliseconds: (duration.inMilliseconds * ratio).toInt(),
      );
      _audioService.seek(newPosition);
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final track = _audioService.currentTrack;
    final position = _audioService.currentPosition;
    final duration = track?.duration ?? Duration.zero;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        _audioService.playPause();
        break;
      case LogicalKeyboardKey.arrowLeft:
        // Seek backward 10 seconds
        final newPos = position - const Duration(seconds: 10);
        _audioService.seek(newPos < Duration.zero ? Duration.zero : newPos);
        break;
      case LogicalKeyboardKey.arrowRight:
        // Seek forward 10 seconds
        final newPos = position + const Duration(seconds: 10);
        _audioService.seek(newPos > duration ? duration : newPos);
        break;
      case LogicalKeyboardKey.arrowUp:
        // Volume up 5%
        final newVolume = (_audioService.volume + 0.05).clamp(0.0, 1.0);
        _audioService.setVolume(newVolume);
        break;
      case LogicalKeyboardKey.arrowDown:
        // Volume down 5%
        final newVolume = (_audioService.volume - 0.05).clamp(0.0, 1.0);
        _audioService.setVolume(newVolume);
        break;
      case LogicalKeyboardKey.keyN:
        // Next track
        _audioService.next();
        break;
      case LogicalKeyboardKey.keyP:
        // Previous track
        _audioService.previous();
        break;
      case LogicalKeyboardKey.keyR:
        // Toggle repeat mode
        _audioService.toggleRepeatMode();
        break;
      case LogicalKeyboardKey.keyL:
        // Toggle favorite
        if (track != null) {
          _toggleFavorite(track);
        }
        break;
    }
  }

  Future<void> _toggleFavorite(JellyfinTrack track) async {
    try {
      final currentFavoriteStatus = track.isFavorite;
      final newFavoriteStatus = !currentFavoriteStatus;

      await _appState.markFavorite(track.id, newFavoriteStatus);
      final updatedTrack = track.copyWith(isFavorite: newFavoriteStatus);
      _audioService.updateCurrentTrack(updatedTrack);

      if (mounted) setState(() {});
      await _appState.refreshFavorites();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newFavoriteStatus ? 'Added to favorites' : 'Removed from favorites'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update favorite: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;

    return StreamBuilder<JellyfinTrack?>(
      stream: _audioService.currentTrackStream,
      initialData: _audioService.currentTrack,
      builder: (context, trackSnapshot) {
        final track = trackSnapshot.data;

        return StreamBuilder<bool>(
          stream: _audioService.playingStream,
          initialData: _audioService.isPlaying,
          builder: (context, playingSnapshot) {
            final isPlaying = playingSnapshot.data ?? false;

            return StreamBuilder<Duration>(
              stream: _audioService.positionStream,
              initialData: _audioService.currentPosition,
              builder: (context, positionSnapshot) {
                final position = positionSnapshot.data ?? Duration.zero;

                return StreamBuilder<Duration?>(
                  stream: _audioService.durationStream,
                  initialData: track?.duration,
                  builder: (context, durationSnapshot) {
                    final duration = durationSnapshot.data ?? track?.duration ?? Duration.zero;

                    if (track == null) {
                      return Scaffold(
                        appBar: AppBar(
                          title: const Text('Now Playing'),
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.music_note, size: 64, color: theme.colorScheme.secondary),
                              const SizedBox(height: 16),
                              Text(
                                'No track playing',
                                style: theme.textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final artwork = _buildArtwork(
                      track: track,
                      isDesktop: isDesktop,
                      theme: theme,
                    );

                    return Focus(
                      autofocus: true,
                      onKeyEvent: (node, event) {
                        _handleKeyEvent(event);
                        return KeyEventResult.handled;
                      },
                      child: Scaffold(
                      body: SafeArea(
                        child: Column(
                          children: [
                            // Header with TabBar
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.expand_more),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                  const Spacer(),
                                  TabBar(
                                    controller: _tabController,
                                    isScrollable: true,
                                    tabAlignment: TabAlignment.center,
                                    labelStyle: theme.textTheme.titleSmall,
                                    tabs: const [
                                      Tab(text: 'Now Playing'),
                                      Tab(text: 'Lyrics'),
                                    ],
                                  ),
                                  const Spacer(),
                                  const SizedBox(width: 48),
                                ],
                              ),
                            ),

                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  // Tab 1: Now Playing (existing content)
                                  _buildNowPlayingTab(
                                    track: track,
                                    isPlaying: isPlaying,
                                    position: position,
                                    duration: duration,
                                    isDesktop: isDesktop,
                                    theme: theme,
                                    artwork: artwork,
                                  ),

                                  // Tab 2: Lyrics
                                  _buildLyricsTab(
                                    track: track,
                                    position: position,
                                    theme: theme,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

  Widget _buildNowPlayingTab({
    required JellyfinTrack track,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    required bool isDesktop,
    required ThemeData theme,
    required Widget artwork,
  }) {
    return Builder(
      builder: (context) {
        final size = MediaQuery.of(context).size;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? size.width * 0.15 : 24,
            vertical: 16,
          ),
          child: Column(
            children: [
              // Top section: Artwork and Track Info
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Artwork - Much larger now
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 500 : size.width * 0.85,
                          maxHeight: isDesktop ? 500 : size.height * 0.5,
                        ),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: artwork,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Track Info - Compact
                    Text(
                      track.name,
                      style: (isDesktop
                              ? theme.textTheme.headlineMedium
                              : theme.textTheme.titleLarge)
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      track.displayArtist,
                      style: (isDesktop
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.bodyLarge)
                          ?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (track.album != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        track.album!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Bottom section: Controls (pinned to bottom)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress Slider
                  LayoutBuilder(
                    builder: (context, constraints) {
                      void scrub(double dx) => _seekFromGesture(
                        dx,
                        constraints.maxWidth,
                        duration,
                      );

                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapDown: (details) => scrub(details.localPosition.dx),
                        onHorizontalDragUpdate: (details) => scrub(details.localPosition.dx),
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 16,
                                ),
                              ),
                              child: Slider(
                                value: _sliderValue(position, duration),
                                min: 0,
                                max: _sliderMax(position, duration),
                                onChanged: duration.inMilliseconds > 0
                                    ? (value) {
                                        _audioService.seek(
                                          Duration(milliseconds: value.toInt()),
                                        );
                                      }
                                    : null,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Volume Slider
                  StreamBuilder<double>(
                    stream: _audioService.volumeStream,
                    initialData: _audioService.volume,
                    builder: (context, volumeSnapshot) {
                      final double volume =
                          volumeSnapshot.data ?? _audioService.volume;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.volume_mute, size: 20),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: theme.colorScheme.tertiary,
                                  inactiveTrackColor: theme.colorScheme.tertiary.withValues(alpha: 0.2),
                                  thumbColor: theme.colorScheme.tertiary,
                                  overlayColor: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                                ),
                                child: Slider(
                                  value: volume,
                                  min: 0,
                                  max: 1,
                                  onChanged: (value) {
                                    _audioService.setVolume(value);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(volume * 100).round()}%',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.volume_up, size: 20),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Playback Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          track.isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: isDesktop ? 32 : 26,
                        ),
                        onPressed: () async {
                          try {
                            final currentFavoriteStatus = track.isFavorite;
                            final newFavoriteStatus = !currentFavoriteStatus;

                            debugPrint('🎯 Favorite button clicked: current=$currentFavoriteStatus, new=$newFavoriteStatus');

                            // Update Jellyfin server (with offline queue support)
                            await _appState.markFavorite(track.id, newFavoriteStatus);

                            // Update track object with new favorite status
                            final updatedTrack = track.copyWith(isFavorite: newFavoriteStatus);
                            debugPrint('🔄 Updating track: old isFavorite=${track.isFavorite}, new isFavorite=${updatedTrack.isFavorite}');
                            _audioService.updateCurrentTrack(updatedTrack);

                            // Force UI rebuild
                            if (mounted) setState(() {});

                            // Refresh favorites list in app state
                            await _appState.refreshFavorites();

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(newFavoriteStatus ? 'Added to favorites' : 'Removed from favorites'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            debugPrint('❌ Error toggling favorite: $e');
                            if (!context.mounted) return;
                            final isOfflineError = e.toString().contains('Offline') ||
                                e.toString().contains('queued');

                            // Update track optimistically even when offline
                            if (isOfflineError) {
                              final currentFavoriteStatus = track.isFavorite;
                              final newFavoriteStatus = !currentFavoriteStatus;
                              final updatedTrack = track.copyWith(isFavorite: newFavoriteStatus);
                              _audioService.updateCurrentTrack(updatedTrack);
                              if (mounted) setState(() {});
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    isOfflineError
                                        ? 'Offline: Favorite will sync when online'
                                        : 'Failed to update favorite: $e'),
                                backgroundColor: isOfflineError ? Colors.orange : theme.colorScheme.error,
                              ),
                            );
                          }
                        },
                        color: track.isFavorite ? Colors.red : null,
                      ),

                      SizedBox(width: isDesktop ? 16 : 4),

                      IconButton(
                        icon: Icon(
                          Icons.skip_previous,
                          size: isDesktop ? 48 : 40,
                        ),
                        onPressed: () => _audioService.previous(),
                      ),

                      SizedBox(width: isDesktop ? 24 : 8),

                      IconButton(
                        icon: Icon(
                          Icons.stop,
                          size: isDesktop ? 40 : 32,
                        ),
                        onPressed: () => _audioService.stop(),
                        color: theme.colorScheme.error,
                      ),

                      SizedBox(width: isDesktop ? 24 : 8),

                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            size: isDesktop ? 56 : 48,
                          ),
                          onPressed: () => _audioService.playPause(),
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),

                      SizedBox(width: isDesktop ? 24 : 8),

                      IconButton(
                        icon: Icon(
                          Icons.skip_next,
                          size: isDesktop ? 48 : 40,
                        ),
                        onPressed: () => _audioService.next(),
                      ),

                      SizedBox(width: isDesktop ? 16 : 4),

                      // Repeat button
                      StreamBuilder<RepeatMode>(
                        stream: _audioService.repeatModeStream,
                        initialData: _audioService.repeatMode,
                        builder: (context, snapshot) {
                          final repeatMode = snapshot.data ?? RepeatMode.off;
                          IconData icon;
                          Color? color;

                          switch (repeatMode) {
                            case RepeatMode.off:
                              icon = Icons.repeat;
                              color = null;
                              break;
                            case RepeatMode.all:
                              icon = Icons.repeat;
                              color = theme.colorScheme.primary;
                              break;
                            case RepeatMode.one:
                              icon = Icons.repeat_one;
                              color = theme.colorScheme.primary;
                              break;
                          }

                          return IconButton(
                            icon: Icon(
                              icon,
                              size: isDesktop ? 32 : 26,
                              color: color,
                            ),
                            onPressed: () => _audioService.toggleRepeatMode(),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLyricsTab({
    required JellyfinTrack track,
    required Duration position,
    required ThemeData theme,
  }) {
    if (_loadingLyrics) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading lyrics...', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    if (_lyricsData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 80,
              color: theme.colorScheme.secondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No lyrics available',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Lyrics not found for this track',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Parse lyrics data
    final lyrics = _lyricsData!['Lyrics'] as List<dynamic>?;
    if (lyrics == null || lyrics.isEmpty) {
      return Center(
        child: Text(
          'Lyrics format not supported',
          style: theme.textTheme.titleMedium,
        ),
      );
    }

    // Convert lyrics to structured format
    final lyricLines = lyrics.map((line) {
      final start = line['Start'] as int?; // ticks
      final text = line['Text'] as String? ?? '';
      return _LyricLine(
        text: text,
        startTicks: start,
      );
    }).toList();

    // Find current lyric based on position
    final currentTicks = position.inMicroseconds * 10; // convert to ticks
    int currentIndex = 0;
    for (int i = 0; i < lyricLines.length; i++) {
      final lineTicks = lyricLines[i].startTicks;
      if (lineTicks != null && lineTicks <= currentTicks) {
        currentIndex = i;
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      itemCount: lyricLines.length,
      itemBuilder: (context, index) {
        final line = lyricLines[index];
        final isCurrent = index == currentIndex;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            line.text,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: isCurrent
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              fontSize: isCurrent ? 24 : 18,
              height: 1.5,
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtwork({
    required JellyfinTrack track,
    required bool isDesktop,
    required ThemeData theme,
  }) {
    final borderRadius = BorderRadius.circular(isDesktop ? 24 : 16);
    final maxWidth = isDesktop ? 800 : 500;
    final imageUrl = track.artworkUrl(maxWidth: maxWidth);
    final placeholder = Icon(
      Icons.album,
      size: isDesktop ? 120 : 80,
      color: theme.colorScheme.onPrimaryContainer,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: theme.colorScheme.primaryContainer,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: AspectRatio(
          aspectRatio: 1,
          child: imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: theme.colorScheme.primaryContainer,
                    child: Center(child: const CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => placeholder,
                  memCacheWidth: maxWidth,
                  maxWidthDiskCache: maxWidth,
                )
              : placeholder,
        ),
      ),
    );
  }
}

class _LyricLine {
  _LyricLine({
    required this.text,
    this.startTicks,
  });

  final String text;
  final int? startTicks; // Jellyfin uses ticks (100 nanoseconds)
}
