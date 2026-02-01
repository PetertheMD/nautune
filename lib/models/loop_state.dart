/// A-B repeat loop state for audio playback.
///
/// Allows users to set a loop region on downloaded/cached tracks,
/// playing between point A (start) and point B (end) repeatedly.
class LoopState {
  /// Loop start point (A marker)
  final Duration? start;

  /// Loop end point (B marker)
  final Duration? end;

  /// Whether the loop is currently active
  final bool isActive;

  const LoopState({
    this.start,
    this.end,
    this.isActive = false,
  });

  /// Check if both markers are set
  bool get hasValidLoop => start != null && end != null && end! > start!;

  /// Check if only the start marker is set (waiting for end)
  bool get isWaitingForEnd => start != null && end == null;

  /// Check if loop has any markers set
  bool get hasMarkers => start != null || end != null;

  /// Get loop duration if valid
  Duration? get loopDuration {
    if (!hasValidLoop) return null;
    return end! - start!;
  }

  /// Format start time as string
  String get formattedStart {
    if (start == null) return '--:--';
    return _formatDuration(start!);
  }

  /// Format end time as string
  String get formattedEnd {
    if (end == null) return '--:--';
    return _formatDuration(end!);
  }

  /// Format loop duration as string
  String get formattedLoopDuration {
    final dur = loopDuration;
    if (dur == null) return '--:--';
    return _formatDuration(dur);
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  LoopState copyWith({
    Duration? start,
    Duration? end,
    bool? isActive,
    bool clearStart = false,
    bool clearEnd = false,
  }) {
    return LoopState(
      start: clearStart ? null : (start ?? this.start),
      end: clearEnd ? null : (end ?? this.end),
      isActive: isActive ?? this.isActive,
    );
  }

  /// Create an empty/cleared loop state
  static const LoopState empty = LoopState();

  @override
  String toString() {
    return 'LoopState(start: $start, end: $end, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoopState &&
        other.start == start &&
        other.end == end &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(start, end, isActive);
}
