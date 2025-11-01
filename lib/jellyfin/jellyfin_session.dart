import 'jellyfin_credentials.dart';

class JellyfinSession {
  JellyfinSession({
    required this.serverUrl,
    required this.username,
    required this.credentials,
    this.selectedLibraryId,
    this.selectedLibraryName,
  });

  final String serverUrl;
  final String username;
  final JellyfinCredentials credentials;
  final String? selectedLibraryId;
  final String? selectedLibraryName;

  static const _unset = Object();

  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'username': username,
      'credentials': credentials.toJson(),
      'selectedLibraryId': selectedLibraryId,
      'selectedLibraryName': selectedLibraryName,
    };
  }

  factory JellyfinSession.fromJson(Map<String, dynamic> json) {
    final rawCredentials =
        json['credentials'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return JellyfinSession(
      serverUrl: json['serverUrl'] as String? ?? '',
      username: json['username'] as String? ?? '',
      credentials: JellyfinCredentials.fromJson(rawCredentials),
      selectedLibraryId: json['selectedLibraryId'] as String?,
      selectedLibraryName: json['selectedLibraryName'] as String?,
    );
  }

  JellyfinSession copyWith({
    String? serverUrl,
    String? username,
    JellyfinCredentials? credentials,
    Object? selectedLibraryId = _unset,
    Object? selectedLibraryName = _unset,
  }) {
    return JellyfinSession(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      credentials: credentials ?? this.credentials,
      selectedLibraryId: selectedLibraryId == _unset
          ? this.selectedLibraryId
          : selectedLibraryId as String?,
      selectedLibraryName: selectedLibraryName == _unset
          ? this.selectedLibraryName
          : selectedLibraryName as String?,
    );
  }
}
