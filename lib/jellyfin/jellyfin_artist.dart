class JellyfinArtist {
  JellyfinArtist({
    required this.id,
    required this.name,
    this.primaryImageTag,
    this.overview,
    this.genres,
    this.albumCount,
    this.songCount,
  });

  final String id;
  final String name;
  final String? primaryImageTag;
  final String? overview;
  final List<String>? genres;
  final int? albumCount;
  final int? songCount;

  factory JellyfinArtist.fromJson(Map<String, dynamic> json) {
    final imageTags = json['ImageTags'];
    final primaryImageTag = imageTags is Map ? (imageTags['Primary'] is String ? imageTags['Primary'] as String : null) : null;

    final rawGenres = json['Genres'];
    final genresList = (rawGenres is List) ? rawGenres.whereType<String>().toList() : null;

    final albumCountVal = json['ChildCount'];
    final albumCount = albumCountVal is int ? albumCountVal : (albumCountVal is num ? albumCountVal.toInt() : null);

    final songCountVal = json['SongCount'];
    final songCount = songCountVal is int ? songCountVal : (songCountVal is num ? songCountVal.toInt() : null);

    return JellyfinArtist(
      id: json['Id'] is String ? json['Id'] as String : '',
      name: json['Name'] is String ? json['Name'] as String : '',
      primaryImageTag: primaryImageTag,
      overview: json['Overview'] is String ? json['Overview'] as String : null,
      genres: genresList,
      albumCount: albumCount,
      songCount: songCount,
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
    };
  }
}
