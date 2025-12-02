import '../jellyfin/jellyfin_album.dart';
import '../jellyfin/jellyfin_artist.dart';
import '../jellyfin/jellyfin_genre.dart';
import '../jellyfin/jellyfin_library.dart';
import '../jellyfin/jellyfin_playlist.dart';
import '../jellyfin/jellyfin_service.dart';
import '../jellyfin/jellyfin_track.dart';
import 'music_repository.dart';

/// Online implementation of MusicRepository.
///
/// Fetches all data from Jellyfin server via JellyfinService.
/// Used when the app is in online mode with network connectivity.
class OnlineRepository implements MusicRepository {
  OnlineRepository({required JellyfinService jellyfinService})
      : _jellyfinService = jellyfinService;

  final JellyfinService _jellyfinService;

  @override
  Future<List<JellyfinLibrary>> getLibraries() async {
    return await _jellyfinService.getLibraries();
  }

  @override
  Future<List<JellyfinAlbum>> getAlbums({
    required String libraryId,
    int startIndex = 0,
    int limit = 50,
  }) async {
    return await _jellyfinService.getAlbums(
      libraryId: libraryId,
      startIndex: startIndex,
      limit: limit,
    );
  }

  @override
  Future<List<JellyfinArtist>> getArtists({
    required String libraryId,
    int startIndex = 0,
    int limit = 50,
  }) async {
    return await _jellyfinService.getArtists(
      libraryId: libraryId,
      startIndex: startIndex,
      limit: limit,
    );
  }

  @override
  Future<List<JellyfinGenre>> getGenres({required String libraryId}) async {
    return await _jellyfinService.getGenres(libraryId: libraryId);
  }

  @override
  Future<List<JellyfinPlaylist>> getPlaylists() async {
    return await _jellyfinService.getPlaylists();
  }

  @override
  Future<List<JellyfinTrack>> getAlbumTracks(String albumId) async {
    return await _jellyfinService.getAlbumTracks(albumId);
  }

  @override
  Future<List<JellyfinAlbum>> getArtistAlbums(String artistId) async {
    return await _jellyfinService.getArtistAlbums(artistId);
  }

  @override
  Future<List<JellyfinTrack>> getPlaylistTracks(String playlistId) async {
    return await _jellyfinService.getPlaylistItems(playlistId);
  }

  @override
  Future<List<JellyfinTrack>> getFavoriteTracks() async {
    return await _jellyfinService.getFavoriteTracks();
  }

  @override
  Future<List<JellyfinTrack>> getRecentlyPlayedTracks({
    required String libraryId,
    int limit = 20,
  }) async {
    return await _jellyfinService.getRecentlyPlayedTracks(
      libraryId: libraryId,
      limit: limit,
    );
  }

  @override
  Future<List<JellyfinAlbum>> getRecentlyAddedAlbums({
    required String libraryId,
    int limit = 20,
  }) async {
    return await _jellyfinService.getRecentlyAdded(
      libraryId: libraryId,
      limit: limit,
    );
  }

  @override
  Future<List<JellyfinTrack>> getMostPlayedTracks({
    required String libraryId,
    int limit = 20,
  }) async {
    return await _jellyfinService.getMostPlayedTracks(
      libraryId: libraryId,
      limit: limit,
    );
  }

  @override
  Future<List<JellyfinAlbum>> getMostPlayedAlbums({
    required String libraryId,
    int limit = 20,
  }) async {
    return await _jellyfinService.getMostPlayedAlbums(
      libraryId: libraryId,
      limit: limit,
    );
  }

  @override
  Future<List<JellyfinTrack>> getLongestTracks({
    required String libraryId,
    int limit = 20,
  }) async {
    return await _jellyfinService.getLongestRuntimeTracks(
      libraryId: libraryId,
      limit: limit,
    );
  }

  @override
  Future<List<JellyfinAlbum>> searchAlbums({
    required String query,
    required String libraryId,
  }) async {
    return await _jellyfinService.searchAlbums(
      query: query,
      libraryId: libraryId,
    );
  }

  @override
  Future<List<JellyfinArtist>> searchArtists({
    required String query,
    required String libraryId,
  }) async {
    return await _jellyfinService.searchArtists(
      query: query,
      libraryId: libraryId,
    );
  }

  @override
  Future<List<JellyfinTrack>> searchTracks({
    required String query,
    required String libraryId,
  }) async {
    return await _jellyfinService.searchTracks(
      query: query,
      libraryId: libraryId,
    );
  }

  @override
  Future<List<JellyfinAlbum>> getGenreAlbums(String genreId) async {
    return await _jellyfinService.getGenreAlbums(genreId);
  }

  @override
  bool get isAvailable => _jellyfinService.isLoggedIn;

  @override
  String get typeName => 'OnlineRepository';
}
