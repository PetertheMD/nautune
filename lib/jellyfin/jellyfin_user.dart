class JellyfinUser {
  JellyfinUser({
    required this.id,
    required this.name,
    this.primaryImageTag,
  });

  final String id;
  final String name;
  final String? primaryImageTag;

  factory JellyfinUser.fromJson(Map<String, dynamic> json) {
    return JellyfinUser(
      id: json['Id'] as String? ?? '',
      name: json['Name'] as String? ?? '',
      primaryImageTag: json['PrimaryImageTag'] as String?,
    );
  }
}
