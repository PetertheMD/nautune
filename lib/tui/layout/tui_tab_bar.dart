import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../jellyfin/jellyfin_track.dart';
import '../tui_theme.dart';
import 'tui_sidebar.dart';

/// Top tab bar showing section tabs and now-playing indicator.
class TuiTabBar extends StatelessWidget {
  const TuiTabBar({
    super.key,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final TuiSidebarItem selectedSection;
  final ValueChanged<TuiSidebarItem> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<NautuneAppState>();
    final audioService = appState.audioPlayerService;

    return Container(
      color: TuiColors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top border
          Text(
            '${TuiChars.topLeft}${TuiChars.horizontal * 200}${TuiChars.topRight}',
            style: TuiTextStyles.normal.copyWith(color: TuiColors.border),
            overflow: TextOverflow.clip,
            maxLines: 1,
          ),
          // Tab content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Text('${TuiChars.vertical} ', style: TuiTextStyles.normal.copyWith(color: TuiColors.border)),
                // Tabs
                for (int i = 0; i < TuiSidebarItem.values.length; i++) ...[
                  _buildTab(TuiSidebarItem.values[i], i + 1),
                  if (i < TuiSidebarItem.values.length - 1)
                    Text(' ${TuiChars.vertical} ', style: TuiTextStyles.dim),
                ],
                // Spacer
                const Spacer(),
                // Now playing indicator
                StreamBuilder<JellyfinTrack?>(
                  stream: audioService.currentTrackStream,
                  builder: (context, snapshot) {
                    final track = snapshot.data;
                    if (track == null) {
                      return const SizedBox.shrink();
                    }
                    return StreamBuilder<bool>(
                      stream: audioService.playingStream,
                      builder: (context, playingSnapshot) {
                        final isPlaying = playingSnapshot.data ?? false;
                        final icon = isPlaying ? TuiChars.playing : TuiChars.paused;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$icon ',
                              style: TuiTextStyles.normal.copyWith(
                                color: isPlaying ? TuiColors.primary : TuiColors.dim,
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: Text(
                                track.name,
                                style: TuiTextStyles.normal.copyWith(
                                  color: TuiColors.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                Text(' ${TuiChars.vertical}', style: TuiTextStyles.normal.copyWith(color: TuiColors.border)),
              ],
            ),
          ),
          // Bottom border
          Text(
            '${TuiChars.bottomLeft}${TuiChars.horizontal * 200}${TuiChars.bottomRight}',
            style: TuiTextStyles.normal.copyWith(color: TuiColors.border),
            overflow: TextOverflow.clip,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildTab(TuiSidebarItem item, int number) {
    final isSelected = item == selectedSection;

    return GestureDetector(
      onTap: () => onSectionSelected(item),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$number:',
            style: TuiTextStyles.dim,
          ),
          Text(
            item.label,
            style: isSelected
                ? TuiTextStyles.normal.copyWith(
                    color: TuiColors.accent,
                    fontWeight: FontWeight.bold,
                  )
                : TuiTextStyles.dim,
          ),
        ],
      ),
    );
  }
}
