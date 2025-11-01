import 'jellyfin_client.dart';
import 'jellyfin_credentials.dart';
import 'jellyfin_user.dart';

/// High-level façade for Nautune to talk to Jellyfin.
class JellyfinService {
  JellyfinService(this.client);

  final JellyfinClient client;

  JellyfinCredentials? _credentials;

  JellyfinCredentials? get credentials => _credentials;

  Future<void> connect({
    required String username,
    required String password,
  }) async {
    _credentials = await client.authenticate(
      username: username,
      password: password,
    );
  }

  Future<List<JellyfinUser>> loadUsers() async {
    final creds = _credentials;
    if (creds == null) {
      throw StateError('Authenticate before requesting users.');
    }
    return client.fetchUsers(creds);
  }
}
