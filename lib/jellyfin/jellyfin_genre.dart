/// Represents a Jellyfin music genre
class JellyfinGenre {
  final String id;
  final String name;
  final int? albumCount;
  final int? trackCount;

  const JellyfinGenre({
    required this.id,
    required this.name,
    this.albumCount,
    this.trackCount,
  });

  factory JellyfinGenre.fromJson(Map<String, dynamic> json) {
    return JellyfinGenre(
      id: json['Id'] as String,
      name: json['Name'] as String,
      albumCount: json['AlbumCount'] as int?,
      trackCount: json['SongCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      if (albumCount != null) 'AlbumCount': albumCount,
      if (trackCount != null) 'SongCount': trackCount,
    };
  }
}
