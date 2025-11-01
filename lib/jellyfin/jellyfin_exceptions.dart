/// Base class for Jellyfin-related errors.
class JellyfinException implements Exception {
  JellyfinException(this.message);

  final String message;

  @override
  String toString() => 'JellyfinException: $message';
}

class JellyfinAuthException extends JellyfinException {
  JellyfinAuthException(super.message);
}

class JellyfinRequestException extends JellyfinException {
  JellyfinRequestException(super.message);
}
