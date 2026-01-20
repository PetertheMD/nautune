/// Data model containing all computed Rewind statistics for a given year
class RewindData {
  /// The year this data is for (null = all time)
  final int? year;

  /// Total number of tracks played
  final int totalPlays;

  /// Total listening time
  final Duration totalTime;

  /// Top artists with play counts
  final List<RewindArtist> topArtists;

  /// Top albums with play counts
  final List<RewindAlbum> topAlbums;

  /// Top tracks with play counts
  final List<RewindTrack> topTracks;

  /// Top genre
  final String? topGenre;

  /// All genres with play counts
  final Map<String, int> genres;

  /// Peak listening month (1-12)
  final int? peakMonth;

  /// Longest listening streak in days
  final int longestStreak;

  /// Unique artists listened to
  final int uniqueArtists;

  /// Unique tracks listened to
  final int uniqueTracks;

  /// Unique albums listened to
  final int uniqueAlbums;

  /// Discovery rate (percentage of unique tracks / total plays)
  final double discoveryRate;

  /// Listening personality archetype
  final ListeningPersonality personality;

  /// Plays by hour of day (0-23)
  final Map<int, int> playsByHour;

  /// Plays by day of week (0=Monday, 6=Sunday)
  final Map<int, int> playsByDayOfWeek;

  RewindData({
    this.year,
    required this.totalPlays,
    required this.totalTime,
    required this.topArtists,
    required this.topAlbums,
    required this.topTracks,
    this.topGenre,
    required this.genres,
    this.peakMonth,
    required this.longestStreak,
    required this.uniqueArtists,
    required this.uniqueTracks,
    required this.uniqueAlbums,
    required this.discoveryRate,
    required this.personality,
    required this.playsByHour,
    required this.playsByDayOfWeek,
  });

  /// Check if there's enough data for a meaningful Rewind
  bool get hasEnoughData => totalPlays >= 10;

  /// Get formatted total time string
  String get formattedTotalTime {
    final hours = totalTime.inHours;
    final minutes = totalTime.inMinutes % 60;
    if (hours > 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'}, $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
  }

  /// Get formatted short time string
  String get shortTotalTime {
    final hours = totalTime.inHours;
    final minutes = totalTime.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Get year display string
  String get yearDisplay => year?.toString() ?? 'All Time';

  /// Get the most active listening hour range
  String get peakHourRange {
    if (playsByHour.isEmpty) return 'N/A';
    final sorted = playsByHour.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final peakHour = sorted.first.key;
    final endHour = (peakHour + 1) % 24;
    return '${_formatHour(peakHour)} - ${_formatHour(endHour)}';
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour > 12) return '${hour - 12} PM';
    return '$hour AM';
  }

  /// Get peak day of week name
  String get peakDayOfWeek {
    if (playsByDayOfWeek.isEmpty) return 'N/A';
    final sorted = playsByDayOfWeek.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[sorted.first.key];
  }

  /// Get month name from number
  static String monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}

/// Artist data for Rewind
class RewindArtist {
  final String name;
  final int playCount;
  final String? id;
  final String? imageTag;

  RewindArtist({
    required this.name,
    required this.playCount,
    this.id,
    this.imageTag,
  });
}

/// Album data for Rewind
class RewindAlbum {
  final String? albumId;
  final String name;
  final String artistName;
  final int playCount;
  final String? imageTag;

  RewindAlbum({
    this.albumId,
    required this.name,
    required this.artistName,
    required this.playCount,
    this.imageTag,
  });
}

/// Track data for Rewind
class RewindTrack {
  final String trackId;
  final String name;
  final String artistName;
  final String? albumName;
  final String? albumId;
  final int playCount;

  RewindTrack({
    required this.trackId,
    required this.name,
    required this.artistName,
    this.albumName,
    this.albumId,
    required this.playCount,
  });
}

/// Listening personality archetype based on listening patterns
enum ListeningPersonality {
  /// Listens to many different artists/tracks
  explorer(
    name: 'Explorer',
    description: 'You\'re always discovering new music!',
    emoji: '🧭',
  ),

  /// High replay rate, sticks to favorites
  loyalist(
    name: 'Loyalist',
    description: 'You know what you love and stick with it!',
    emoji: '💎',
  ),

  /// Primarily listens late at night (10pm-4am)
  nightOwl(
    name: 'Night Owl',
    description: 'Your music hits different after midnight.',
    emoji: '🦉',
  ),

  /// Primarily listens early morning (5am-8am)
  earlyBird(
    name: 'Early Bird',
    description: 'You start your day with music!',
    emoji: '🌅',
  ),

  /// High weekend listening
  weekendWarrior(
    name: 'Weekend Warrior',
    description: 'Weekends are made for music!',
    emoji: '🎉',
  ),

  /// Long listening sessions (marathon sessions)
  marathoner(
    name: 'Marathoner',
    description: 'You love long listening sessions!',
    emoji: '🏃',
  ),

  /// High genre diversity
  eclectic(
    name: 'Eclectic',
    description: 'Your taste spans all genres!',
    emoji: '🎨',
  ),

  /// Single genre focus
  specialist(
    name: 'Specialist',
    description: 'You\'ve found your sound!',
    emoji: '🎯',
  ),

  /// Default/balanced listener
  balanced(
    name: 'Balanced',
    description: 'A well-rounded music lover!',
    emoji: '⚖️',
  );

  final String name;
  final String description;
  final String emoji;

  const ListeningPersonality({
    required this.name,
    required this.description,
    required this.emoji,
  });
}
