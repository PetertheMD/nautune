import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../jellyfin/jellyfin_track.dart';
import '../widgets/jellyfin_image.dart';
import '../widgets/now_playing_bar.dart';

/// Screen to display all tracks in a clean scrollable list
class AllTracksScreen extends StatelessWidget {
  const AllTracksScreen({
    super.key,
    required this.title,
    required this.tracks,
    this.subtitle,
    this.accentColor,
  });

  final String title;
  final String? subtitle;
  final List<JellyfinTrack> tracks;
  final Color? accentColor;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = Provider.of<NautuneAppState>(context);
    final audioService = appState.audioPlayerService;
    final effectiveAccent = accentColor ?? theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            if (subtitle != null)
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          // Shuffle button
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'Shuffle All',
            onPressed: tracks.isNotEmpty
                ? () async {
                    final shuffled = List<JellyfinTrack>.from(tracks)..shuffle();
                    await audioService.playTrack(
                      shuffled.first,
                      queueContext: shuffled,
                    );
                  }
                : null,
          ),
          // Play all button
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Play All',
            onPressed: tracks.isNotEmpty
                ? () async {
                    await audioService.playTrack(
                      tracks.first,
                      queueContext: tracks,
                    );
                  }
                : null,
          ),
        ],
      ),
      body: tracks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_off,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tracks available',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                final duration = track.runTimeTicks != null
                    ? Duration(microseconds: track.runTimeTicks! ~/ 10)
                    : Duration.zero;

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: track.albumPrimaryImageTag != null
                          ? JellyfinImage(
                              itemId: track.albumId ?? track.id,
                              imageTag: track.albumPrimaryImageTag,
                              maxWidth: 100,
                              boxFit: BoxFit.cover,
                            )
                          : Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.music_note,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ),
                  title: Text(
                    track.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    track.displayArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Favorite indicator
                      if (track.isFavorite)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.favorite,
                            size: 16,
                            color: Colors.red.withValues(alpha: 0.7),
                          ),
                        ),
                      // Duration
                      Text(
                        _formatDuration(duration),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      // Rank badge for popular tracks (first 5)
                      if (index < 5) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: effectiveAccent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: effectiveAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () async {
                    await audioService.playTrack(
                      track,
                      queueContext: tracks,
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: NowPlayingBar(
        audioService: audioService,
        appState: appState,
      ),
    );
  }
}
