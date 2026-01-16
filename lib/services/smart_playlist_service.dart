import 'dart:math';
import 'package:flutter/foundation.dart';
import '../jellyfin/jellyfin_service.dart';
import '../jellyfin/jellyfin_track.dart';

/// Mood categories for smart playlist generation
enum Mood {
  chill,
  energetic,
  melancholy,
  upbeat;

  String get displayName {
    switch (this) {
      case Mood.chill:
        return 'Chill';
      case Mood.energetic:
        return 'Energetic';
      case Mood.melancholy:
        return 'Melancholy';
      case Mood.upbeat:
        return 'Upbeat';
    }
  }

  String get subtitle {
    switch (this) {
      case Mood.chill:
        return 'Jazz, Blues, Ambient...';
      case Mood.energetic:
        return 'Rock, EDM, Metal...';
      case Mood.melancholy:
        return 'Classical, Indie, Folk...';
      case Mood.upbeat:
        return 'Pop, Funk, Disco...';
    }
  }
}

/// Service for generating smart playlists based on genre-to-mood mapping
class SmartPlaylistService {
  final JellyfinService _jellyfinService;
  final String _libraryId;
  final Random _random = Random();

  SmartPlaylistService({
    required JellyfinService jellyfinService,
    required String libraryId,
  })  : _jellyfinService = jellyfinService,
        _libraryId = libraryId;

  /// Genre-to-mood mapping (case-insensitive matching)
  static const Map<String, Mood> _genreMoodMap = {
    // Chill genres
    'jazz': Mood.chill,
    'blues': Mood.chill,
    'ambient': Mood.chill,
    'lounge': Mood.chill,
    'bossa nova': Mood.chill,
    'bossa': Mood.chill,
    'chillout': Mood.chill,
    'chill out': Mood.chill,
    'chill-out': Mood.chill,
    'downtempo': Mood.chill,
    'easy listening': Mood.chill,
    'soul': Mood.chill,
    'smooth jazz': Mood.chill,
    'trip hop': Mood.chill,
    'trip-hop': Mood.chill,
    'new age': Mood.chill,
    'world': Mood.chill,

    // Energetic genres
    'rock': Mood.energetic,
    'metal': Mood.energetic,
    'heavy metal': Mood.energetic,
    'punk': Mood.energetic,
    'punk rock': Mood.energetic,
    'electronic': Mood.energetic,
    'dance': Mood.energetic,
    'edm': Mood.energetic,
    'drum and bass': Mood.energetic,
    'drum & bass': Mood.energetic,
    'dnb': Mood.energetic,
    'house': Mood.energetic,
    'techno': Mood.energetic,
    'hard rock': Mood.energetic,
    'alternative rock': Mood.energetic,
    'alternative': Mood.energetic,
    'hardcore': Mood.energetic,
    'industrial': Mood.energetic,
    'trance': Mood.energetic,
    'dubstep': Mood.energetic,
    'grunge': Mood.energetic,
    'progressive rock': Mood.energetic,

    // Melancholy genres
    'classical': Mood.melancholy,
    'indie': Mood.melancholy,
    'folk': Mood.melancholy,
    'acoustic': Mood.melancholy,
    'singer-songwriter': Mood.melancholy,
    'singer songwriter': Mood.melancholy,
    'sad': Mood.melancholy,
    'piano': Mood.melancholy,
    'orchestral': Mood.melancholy,
    'soundtrack': Mood.melancholy,
    'instrumental': Mood.melancholy,
    'chamber': Mood.melancholy,
    'baroque': Mood.melancholy,
    'romantic': Mood.melancholy,
    'post-rock': Mood.melancholy,
    'post rock': Mood.melancholy,
    'shoegaze': Mood.melancholy,
    'dream pop': Mood.melancholy,
    'slowcore': Mood.melancholy,
    'dark ambient': Mood.melancholy,

    // Upbeat genres
    'pop': Mood.upbeat,
    'funk': Mood.upbeat,
    'disco': Mood.upbeat,
    'r&b': Mood.upbeat,
    'rnb': Mood.upbeat,
    'rhythm and blues': Mood.upbeat,
    'reggae': Mood.upbeat,
    'latin': Mood.upbeat,
    'hip hop': Mood.upbeat,
    'hip-hop': Mood.upbeat,
    'rap': Mood.upbeat,
    'k-pop': Mood.upbeat,
    'kpop': Mood.upbeat,
    'j-pop': Mood.upbeat,
    'jpop': Mood.upbeat,
    'ska': Mood.upbeat,
    'motown': Mood.upbeat,
    'afrobeat': Mood.upbeat,
    'salsa': Mood.upbeat,
    'samba': Mood.upbeat,
    'cumbia': Mood.upbeat,
    'dancehall': Mood.upbeat,
    'electropop': Mood.upbeat,
    'synth-pop': Mood.upbeat,
    'synthpop': Mood.upbeat,
    'nu-disco': Mood.upbeat,
  };

  /// Get the mood for a given genre (case-insensitive)
  Mood? getMoodForGenre(String genre) {
    final normalized = genre.toLowerCase().trim();
    return _genreMoodMap[normalized];
  }

  /// Analyze a track's primary mood based on its genres
  Mood? getTrackMood(JellyfinTrack track) {
    final genres = track.genres;
    if (genres == null || genres.isEmpty) return null;

    // Count mood occurrences across all genres
    final moodCounts = <Mood, int>{};
    for (final genre in genres) {
      final mood = getMoodForGenre(genre);
      if (mood != null) {
        moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
      }
    }

    if (moodCounts.isEmpty) return null;

    // Return the mood with the highest count
    return moodCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  /// Get all tracks that match a specific mood
  Future<List<JellyfinTrack>> getTracksByMood(Mood mood, {int limit = 50}) async {
    try {
      // Get all tracks from the library
      final allTracks = await _jellyfinService.getAllTracks(libraryId: _libraryId);

      // Filter by mood
      final matchingTracks = <JellyfinTrack>[];
      for (final track in allTracks) {
        final trackMood = getTrackMood(track);
        if (trackMood == mood) {
          matchingTracks.add(track);
        }
      }

      debugPrint('SmartPlaylist: Found ${matchingTracks.length} tracks for mood ${mood.displayName}');

      // Shuffle and limit
      matchingTracks.shuffle(_random);
      if (matchingTracks.length > limit) {
        return matchingTracks.sublist(0, limit);
      }

      return matchingTracks;
    } catch (e) {
      debugPrint('SmartPlaylist: Error getting tracks by mood: $e');
      return [];
    }
  }

  /// Generate a shuffled mood mix playlist
  Future<List<JellyfinTrack>> generateMoodMix(Mood mood, {int limit = 50}) async {
    final tracks = await getTracksByMood(mood, limit: limit);
    debugPrint('SmartPlaylist: Generated ${mood.displayName} mix with ${tracks.length} tracks');
    return tracks;
  }

  /// Check if any tracks are available for a mood
  Future<bool> hasMoodTracks(Mood mood) async {
    final tracks = await getTracksByMood(mood, limit: 1);
    return tracks.isNotEmpty;
  }

  /// Get track counts for all moods (for UI display)
  Future<Map<Mood, int>> getMoodTrackCounts() async {
    try {
      final allTracks = await _jellyfinService.getAllTracks(libraryId: _libraryId);
      final counts = <Mood, int>{};

      for (final track in allTracks) {
        final mood = getTrackMood(track);
        if (mood != null) {
          counts[mood] = (counts[mood] ?? 0) + 1;
        }
      }

      return counts;
    } catch (e) {
      debugPrint('SmartPlaylist: Error getting mood counts: $e');
      return {};
    }
  }
}
