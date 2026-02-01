import 'package:flutter/material.dart';

import '../../models/loop_state.dart';
import '../tui_theme.dart';

/// An ASCII-style progress bar widget.
/// Renders as: [=========>          ] 2:34 / 4:12
/// With loop: [====|--[====]--|=====>       ] 2:34 / 4:12 [LOOP A:1:00-B:2:00]
class TuiProgressBar extends StatelessWidget {
  const TuiProgressBar({
    super.key,
    required this.position,
    required this.duration,
    this.width = 30,
    this.showTime = true,
    this.loopState,
  });

  final Duration position;
  final Duration duration;
  final int width;
  final bool showTime;
  final LoopState? loopState;

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    // Calculate bar segments
    final innerWidth = width - 2; // Subtract brackets
    final filledCount = (progress * innerWidth).floor();
    final hasHead = filledCount < innerWidth;

    // Build bar with loop markers if present
    final loop = loopState;
    String bar;

    if (loop != null && loop.hasValidLoop && duration.inMilliseconds > 0) {
      // Calculate loop marker positions
      final loopStartPos = (loop.start!.inMilliseconds / duration.inMilliseconds * innerWidth).floor();
      final loopEndPos = (loop.end!.inMilliseconds / duration.inMilliseconds * innerWidth).floor();

      // Build bar with loop region
      final buffer = StringBuffer();
      buffer.write(TuiChars.progressLeft);

      for (int i = 0; i < innerWidth; i++) {
        final isLoopStart = i == loopStartPos;
        final isLoopEnd = i == loopEndPos;
        final inLoop = i >= loopStartPos && i <= loopEndPos;

        if (isLoopStart) {
          buffer.write('[');
        } else if (isLoopEnd) {
          buffer.write(']');
        } else if (i == filledCount && i < innerWidth) {
          buffer.write(TuiChars.progressHead);
        } else if (i < filledCount) {
          buffer.write(inLoop && loop.isActive ? '▓' : TuiChars.progressFilled);
        } else {
          buffer.write(inLoop && loop.isActive ? '░' : TuiChars.progressEmpty);
        }
      }

      buffer.write(TuiChars.progressRight);
      bar = buffer.toString();
    } else {
      final filled = TuiChars.progressFilled * filledCount;
      final head = hasHead ? TuiChars.progressHead : '';
      final empty = TuiChars.progressEmpty * (innerWidth - filledCount - (hasHead ? 1 : 0));
      bar = '${TuiChars.progressLeft}$filled$head$empty${TuiChars.progressRight}';
    }

    if (!showTime) {
      return Text(bar, style: TuiTextStyles.normal);
    }

    final posStr = _formatDuration(position);
    final durStr = _formatDuration(duration);

    // Add loop indicator if active
    final loopIndicator = (loop != null && loop.isActive)
        ? ' [LOOP ${loop.formattedStart}-${loop.formattedEnd}]'
        : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(bar, style: TuiTextStyles.accent),
        const SizedBox(width: 8),
        Text('$posStr / $durStr', style: TuiTextStyles.dim),
        if (loopIndicator.isNotEmpty)
          Text(loopIndicator, style: TuiTextStyles.accent.copyWith(color: TuiColors.primary)),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString()}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// A simple volume bar indicator.
/// Renders as: Vol: [████████░░] 80%
class TuiVolumeBar extends StatelessWidget {
  const TuiVolumeBar({
    super.key,
    required this.volume,
    this.width = 10,
    this.showLabel = true,
  });

  final double volume;
  final int width;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final filled = (volume * width).round();
    final empty = width - filled;

    final filledChar = '█';
    final emptyChar = '░';

    final bar = filledChar * filled + emptyChar * empty;
    final percent = (volume * 100).round();

    if (!showLabel) {
      return Text('[$bar]', style: TuiTextStyles.normal);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Vol: ', style: TuiTextStyles.dim),
        Text('[$bar]', style: TuiTextStyles.accent),
        Text(' $percent%', style: TuiTextStyles.dim),
      ],
    );
  }
}
