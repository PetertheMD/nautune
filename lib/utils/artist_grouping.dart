import '../jellyfin/jellyfin_artist.dart';

/// Utility class for grouping artists.
/// 
/// When artist grouping is enabled, artists like "Alan Jackson" and 
/// "Alan Jackson feat. Lee Ann Womack" are combined into one entry,
/// with the artist that has artwork being preferred as the primary.
class ArtistGrouping {
  /// Common separators that indicate a featured artist or collaboration.
  /// Regex pattern to match common artist separators.
  /// Matches " feat", " ft", " with", " x ", " & ", " vs", " pres", " presents", " starring", " duet with"
  /// followed by optional dot, and spaces.
  /// Also matches simple comma separator.
  static final _separatorRegex = RegExp(
    r'\s+(?:feat|ft|featuring|with|w\/|&|x|vs|pres|presents|starring|duet with)\.?\s+|,\s*',
    caseSensitive: false,
  );

  /// Exceptions for artists that contain separators (like commas) in their name
  /// and should not be split.
  static const _exceptions = [
    'AC,DC',
    'AC/DC',
    'Tyler, The Creator',
    'Earth, Wind & Fire',
    'Crosby, Stills, Nash & Young',
    'Emerson, Lake & Palmer',
    'Peter, Bjorn and John',
    'Simon & Garfunkel',
    'Hall & Oates',
    'Brooks & Dunn',
    'Captain & Tennille',
    'Seals & Crofts',
    'Mumford & Sons',
    'Blood, Sweat & Tears',
    'Medeski, Martin & Wood',
    'The Good, The Bad & The Queen',
    'Dave Dee, Dozy, Beaky, Mick & Tich',
    'Ike & Tina Turner',
    'Ashford & Simpson',
    'Peaches & Herb',
    'Sam & Dave',
    'Zager & Evans',
    'Bell & James',
    'Country Joe and the Fish',
  ];

  /// Extract the base artist name from a potentially collaborative artist name.
  /// 
  /// For example:
  /// - "Alan Jackson feat. Lee Ann Womack" -> "Alan Jackson"
  /// - "Drake & Future" -> "Drake"
  /// - "Azahriah x Desh" -> "Azahriah"
  /// - "Artist A, Artist B" -> "Artist A"
  static String extractBaseName(String artistName, {Set<String>? protectedNames}) {
    // 1. Check dynamic protected names (e.g. from MusicBrainz IDs)
    if (protectedNames != null) {
      for (final protected in protectedNames) {
         if (artistName.toLowerCase().startsWith(protected.toLowerCase())) {
           final rest = artistName.substring(protected.length);
           if (rest.trim().isEmpty || _separatorRegex.matchAsPrefix(rest) != null) {
             return artistName.substring(0, protected.length);
           }
         }
      }
    }

    // 2. Check exceptions
    for (final exception in _exceptions) {
      if (artistName.toLowerCase().startsWith(exception.toLowerCase())) {
        final rest = artistName.substring(exception.length);
        // If the match is exact, or followed by a separator (start of rest matches regex)
        // or rest is just whitespace
        if (rest.trim().isEmpty || _separatorRegex.matchAsPrefix(rest) != null) {
          return artistName.substring(0, exception.length);
        }
      }
    }

    // 2. Try to match any of the separators
    final match = _separatorRegex.firstMatch(artistName);
    
    if (match != null) {
      // Return everything before the match start
      final base = artistName.substring(0, match.start).trim();
      if (base.isNotEmpty) {
        return base;
      }
    }
    
    return artistName.trim();
  }

  /// Normalize an artist name for comparison.
  /// Removes punctuation, extra spaces, and converts to lowercase.
  static String normalizeForComparison(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  /// Group a list of artists by their base name.
  /// 
  /// Returns a new list where artists with the same base name are grouped together.
  /// The primary artist (the one shown in the list) is chosen by:
  /// 1. Prefer the artist with artwork (primaryImageTag is not null)
  /// 2. Prefer the shorter name (likely the "base" artist)
  /// 3. Prefer higher song count
  static List<JellyfinArtist> groupArtists(List<JellyfinArtist> artists) {
    if (artists.isEmpty) return artists;
    
    // Group artists by their normalized base name
    final Map<String, List<JellyfinArtist>> groups = {};

    // 1. Identify "Protected" names: Artists that have a MusicBrainz capability/ID
    // implying they are a valid entity and shouldn't be split.
    final Set<String> protectedNames = {};
    for (final artist in artists) {
      if (artist.providerIds != null && artist.providerIds!.isNotEmpty) {
        // If it has provider IDs (like MusicBrainz), it's likely a valid artist name
        // that shouldn't be split (e.g. "Earth, Wind & Fire").
        protectedNames.add(artist.name);
      }
    }
    
    for (final artist in artists) {
      final baseName = extractBaseName(artist.name, protectedNames: protectedNames);
      final normalizedBase = normalizeForComparison(baseName);
      
      groups.putIfAbsent(normalizedBase, () => []).add(artist);
    }
    
    // For each group, select the best primary artist and combine IDs
    final List<JellyfinArtist> result = [];
    
    for (final group in groups.values) {
      if (group.length == 1) {
        // No grouping needed
        result.add(group.first);
      } else {
        // Sort to find the best primary artist
        group.sort((a, b) {
          // 1. Prefer artists with artwork
          final aHasArt = a.primaryImageTag != null ? 0 : 1;
          final bHasArt = b.primaryImageTag != null ? 0 : 1;
          if (aHasArt != bHasArt) return aHasArt.compareTo(bHasArt);
          
          // 2. Prefer shorter names (more likely to be the "base" artist)
          final nameLengthCompare = a.name.length.compareTo(b.name.length);
          if (nameLengthCompare != 0) return nameLengthCompare;
          
          // 3. Prefer higher song count
          final aSongCount = a.songCount ?? 0;
          final bSongCount = b.songCount ?? 0;
          return bSongCount.compareTo(aSongCount);
        });
        
        final primary = group.first;
        final additionalIds = group
            .skip(1)
            .map((a) => a.id)
            .toList();
        
        // Calculate combined stats
        int totalSongCount = 0;
        int totalAlbumCount = 0;
        for (final artist in group) {
          totalSongCount += artist.songCount ?? 0;
          totalAlbumCount += artist.albumCount ?? 0;
        }
        
        // Create a new artist with combined data
        result.add(primary.copyWith(
          additionalIds: additionalIds.isNotEmpty ? additionalIds : null,
          songCount: totalSongCount > 0 ? totalSongCount : null,
          albumCount: totalAlbumCount > 0 ? totalAlbumCount : null,
        ));
      }
    }
    
    // Sort the result by name
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    return result;
  }
}
