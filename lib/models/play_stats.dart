/// Statistics for a single track's play history
class TrackPlayStats {
  final String trackId;
  final int playCount;
  final DateTime? lastPlayed;
  final Duration totalListenTime;

  TrackPlayStats({
    required this.trackId,
    this.playCount = 0,
    this.lastPlayed,
    this.totalListenTime = Duration.zero,
  });

  /// Create a copy with updated values
  TrackPlayStats copyWith({
    String? trackId,
    int? playCount,
    DateTime? lastPlayed,
    Duration? totalListenTime,
  }) {
    return TrackPlayStats(
      trackId: trackId ?? this.trackId,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      totalListenTime: totalListenTime ?? this.totalListenTime,
    );
  }

  /// Record a play completion
  TrackPlayStats recordPlay(Duration listenDuration) {
    return TrackPlayStats(
      trackId: trackId,
      playCount: playCount + 1,
      lastPlayed: DateTime.now(),
      totalListenTime: totalListenTime + listenDuration,
    );
  }

  /// Increment play count without adding time
  TrackPlayStats incrementPlayCount() {
    return TrackPlayStats(
      trackId: trackId,
      playCount: playCount + 1,
      lastPlayed: DateTime.now(),
      totalListenTime: totalListenTime,
    );
  }

  /// Add listen time without incrementing play count
  TrackPlayStats addListenTime(Duration duration) {
    return TrackPlayStats(
      trackId: trackId,
      playCount: playCount,
      lastPlayed: DateTime.now(),
      totalListenTime: totalListenTime + duration,
    );
  }

  /// Average listen duration per play
  Duration get averageListenDuration {
    if (playCount == 0) return Duration.zero;
    return Duration(milliseconds: totalListenTime.inMilliseconds ~/ playCount);
  }

  /// Check if track was played in the last N days
  bool wasPlayedInLast(Duration duration) {
    if (lastPlayed == null) return false;
    return DateTime.now().difference(lastPlayed!) < duration;
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'trackId': trackId,
      'playCount': playCount,
      'lastPlayed': lastPlayed?.toIso8601String(),
      'totalListenTimeMs': totalListenTime.inMilliseconds,
    };
  }

  /// Create from JSON
  factory TrackPlayStats.fromJson(Map<String, dynamic> json) {
    return TrackPlayStats(
      trackId: json['trackId'] as String,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      lastPlayed: json['lastPlayed'] != null
          ? DateTime.tryParse(json['lastPlayed'] as String)
          : null,
      totalListenTime: Duration(
        milliseconds: (json['totalListenTimeMs'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// Aggregated play statistics
class PlayStatsAggregate {
  final Map<String, TrackPlayStats> _stats;

  PlayStatsAggregate([Map<String, TrackPlayStats>? stats])
      : _stats = stats ?? {};

  /// Get stats for a specific track
  TrackPlayStats? getStats(String trackId) => _stats[trackId];

  /// Get all stats
  Map<String, TrackPlayStats> get allStats => Map.unmodifiable(_stats);

  /// Total number of tracks with stats
  int get trackCount => _stats.length;

  /// Total plays across all tracks
  int get totalPlays => _stats.values.fold(0, (sum, s) => sum + s.playCount);

  /// Total listen time across all tracks
  Duration get totalListenTime => _stats.values.fold(
        Duration.zero,
        (sum, s) => sum + s.totalListenTime,
      );

  /// Record a play for a track
  void recordPlay(String trackId, Duration listenDuration) {
    final existing = _stats[trackId];
    if (existing != null) {
      _stats[trackId] = existing.recordPlay(listenDuration);
    } else {
      _stats[trackId] = TrackPlayStats(
        trackId: trackId,
        playCount: 1,
        lastPlayed: DateTime.now(),
        totalListenTime: listenDuration,
      );
    }
  }

  /// Increment play count for a track
  void incrementPlayCount(String trackId) {
    final existing = _stats[trackId];
    if (existing != null) {
      _stats[trackId] = existing.incrementPlayCount();
    } else {
      _stats[trackId] = TrackPlayStats(
        trackId: trackId,
        playCount: 1,
        lastPlayed: DateTime.now(),
        totalListenTime: Duration.zero,
      );
    }
  }

  /// Add listen time for a track
  void addListenTime(String trackId, Duration duration) {
    final existing = _stats[trackId];
    if (existing != null) {
      _stats[trackId] = existing.addListenTime(duration);
    } else {
      // If we're adding time but it wasn't tracked, assume 1 play
      _stats[trackId] = TrackPlayStats(
        trackId: trackId,
        playCount: 1,
        lastPlayed: DateTime.now(),
        totalListenTime: duration,
      );
    }
  }

  /// Get top played tracks
  List<TrackPlayStats> getTopPlayed(int count) {
    final sorted = _stats.values.toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    return sorted.take(count).toList();
  }

  /// Get tracks played in the last N days
  List<TrackPlayStats> getRecentlyPlayed(Duration duration) {
    return _stats.values
        .where((s) => s.wasPlayedInLast(duration))
        .toList()
      ..sort((a, b) {
        final aTime = a.lastPlayed ?? DateTime(2000);
        final bTime = b.lastPlayed ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
  }

  /// Get unplayed track IDs (tracks with 0 plays)
  Set<String> getUnplayedTrackIds(Set<String> allTrackIds) {
    return allTrackIds.difference(
      _stats.entries
          .where((e) => e.value.playCount > 0)
          .map((e) => e.key)
          .toSet(),
    );
  }

  /// Get track IDs not played in the last N days
  Set<String> getStaleTrackIds(Duration staleThreshold) {
    final cutoff = DateTime.now().subtract(staleThreshold);
    return _stats.entries
        .where((e) {
          final lastPlayed = e.value.lastPlayed;
          return lastPlayed == null || lastPlayed.isBefore(cutoff);
        })
        .map((e) => e.key)
        .toSet();
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'stats': _stats.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  /// Create from JSON
  factory PlayStatsAggregate.fromJson(Map<String, dynamic> json) {
    final statsMap = json['stats'] as Map?;
    if (statsMap == null) return PlayStatsAggregate();

    final parsed = <String, TrackPlayStats>{};
    for (final entry in statsMap.entries) {
      final trackId = entry.key as String;
      final data = entry.value;
      if (data is Map) {
        parsed[trackId] = TrackPlayStats.fromJson(Map<String, dynamic>.from(data));
      }
    }
    return PlayStatsAggregate(parsed);
  }
}
