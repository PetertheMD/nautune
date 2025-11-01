import 'package:http/http.dart' as http;

import 'jellyfin_client.dart';
import 'jellyfin_session.dart';
import 'jellyfin_user.dart';
import 'jellyfin_library.dart';

/// High-level façade for Nautune to talk to Jellyfin.
class JellyfinService {
  JellyfinService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  JellyfinClient? _client;
  JellyfinSession? _session;

  JellyfinSession? get session => _session;

  Future<JellyfinSession> connect({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final normalizedUrl = _normalizeServerUrl(serverUrl);
    final client = JellyfinClient(
      serverUrl: normalizedUrl,
      httpClient: _httpClient,
    );
    final credentials = await client.authenticate(
      username: username,
      password: password,
    );

    final session = JellyfinSession(
      serverUrl: normalizedUrl,
      username: username,
      credentials: credentials,
    );

    _client = client;
    _session = session;

    return session;
  }

  void restoreSession(JellyfinSession session) {
    _client = JellyfinClient(
      serverUrl: session.serverUrl,
      httpClient: _httpClient,
    );
    _session = session;
  }

  void clearSession() {
    _client = null;
    _session = null;
  }

  Future<List<JellyfinUser>> loadUsers() async {
    final client = _client;
    final session = _session;
    if (client == null || session == null) {
      throw StateError('Authenticate before requesting users.');
    }
    return client.fetchUsers(session.credentials);
  }

  Future<List<JellyfinLibrary>> loadLibraries() async {
    final client = _client;
    final session = _session;
    if (client == null || session == null) {
      throw StateError('Authenticate before requesting libraries.');
    }
    return client.fetchLibraries(session.credentials);
  }

  String _normalizeServerUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
