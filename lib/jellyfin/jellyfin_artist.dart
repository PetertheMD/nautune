class JellyfinArtist {
  JellyfinArtist({
    required this.id,
    required this.name,
    this.primaryImageTag,
    this.overview,
    this.genres,
    this.albumCount,
    this.songCount,
    this.playCount,
    this.providerIds,
    this.additionalIds,
  });

  final String id;
  final String name;
  final String? primaryImageTag;
  final String? overview;
  final List<String>? genres;
  final int? albumCount;
  final int? songCount;
  final int? playCount;
  final Map<String, String>? providerIds;
  /// Additional artist IDs that have been grouped into this artist.
  /// Used when artist grouping is enabled to combine "Artist" with "Artist feat. X".
  final List<String>? additionalIds;

  /// Returns all artist IDs including the primary ID and any additional grouped IDs.
  List<String> get allIds => [id, ...?additionalIds];

  /// Creates a copy of this artist with the given fields replaced.
  JellyfinArtist copyWith({
    String? id,
    String? name,
    String? primaryImageTag,
    String? overview,
    List<String>? genres,
    int? albumCount,
    int? songCount,
    int? playCount,
    Map<String, String>? providerIds,
    List<String>? additionalIds,
  }) {
    return JellyfinArtist(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryImageTag: primaryImageTag ?? this.primaryImageTag,
      overview: overview ?? this.overview,
      genres: genres ?? this.genres,
      albumCount: albumCount ?? this.albumCount,
      songCount: songCount ?? this.songCount,
      playCount: playCount ?? this.playCount,
      providerIds: providerIds ?? this.providerIds,
      additionalIds: additionalIds ?? this.additionalIds,
    );
  }

  factory JellyfinArtist.fromJson(Map<String, dynamic> json) {
    final imageTags = json['ImageTags'];
    final primaryImageTag = imageTags is Map ? (imageTags['Primary'] is String ? imageTags['Primary'] as String : null) : null;

    final rawGenres = json['Genres'];
    final genresList = (rawGenres is List) ? rawGenres.whereType<String>().toList() : null;

    final albumCountVal = json['ChildCount'];
    final albumCount = albumCountVal is int ? albumCountVal : (albumCountVal is num ? albumCountVal.toInt() : null);

    final songCountVal = json['SongCount'];
    final songCount = songCountVal is int ? songCountVal : (songCountVal is num ? songCountVal.toInt() : null);

    // Parse play count from UserData
    int? playCount;
    final userData = json['UserData'];
    if (userData is Map) {
      final pc = userData['PlayCount'];
      if (pc is int) {
        playCount = pc;
      } else if (pc is num) {
        playCount = pc.toInt();
      }
    }

    // Parse provider IDs (MusicBrainz, etc.)
    Map<String, String>? providerIds;
    final rawProviderIds = json['ProviderIds'];
    if (rawProviderIds is Map) {
      providerIds = {};
      rawProviderIds.forEach((key, value) {
        if (key is String && value != null) {
          providerIds![key] = value.toString();
        }
      });
      if (providerIds.isEmpty) providerIds = null;
    }

    return JellyfinArtist(
      id: json['Id'] is String ? json['Id'] as String : '',
      name: json['Name'] is String ? json['Name'] as String : '',
      primaryImageTag: primaryImageTag,
      overview: json['Overview'] is String ? json['Overview'] as String : null,
      genres: genresList,
      albumCount: albumCount,
      songCount: songCount,
      playCount: playCount,
      providerIds: providerIds,
      additionalIds: null, // Initialized as null from JSON
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      if (primaryImageTag != null) 'ImageTags': {'Primary': primaryImageTag},
      'Overview': overview,
      if (genres != null) 'Genres': genres,
      'ChildCount': albumCount,
      'SongCount': songCount,
      if (providerIds != null) 'ProviderIds': providerIds,
      if (additionalIds != null) 'AdditionalIds': additionalIds,
    };
  }
}
