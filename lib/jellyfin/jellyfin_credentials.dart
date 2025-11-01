class JellyfinCredentials {
  const JellyfinCredentials({
    required this.accessToken,
    required this.userId,
  });

  final String accessToken;
  final String userId;

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'userId': userId,
    };
  }

  factory JellyfinCredentials.fromJson(Map<String, dynamic> json) {
    return JellyfinCredentials(
      accessToken: json['accessToken'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
    );
  }
}
