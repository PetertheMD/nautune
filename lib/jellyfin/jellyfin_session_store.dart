import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'jellyfin_session.dart';

class JellyfinSessionStore {
  JellyfinSessionStore({SharedPreferences? preferences})
      : _preferences = preferences;

  static const _sessionKey = 'nautune_jellyfin_session';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<JellyfinSession?> load() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) {
      return null;
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return JellyfinSession.fromJson(json);
    } catch (_) {
      await prefs.remove(_sessionKey);
      return null;
    }
  }

  Future<void> save(JellyfinSession session) async {
    final prefs = await _prefs();
    await prefs.setString(
      _sessionKey,
      jsonEncode(session.toJson()),
    );
  }

  Future<void> clear() async {
    final prefs = await _prefs();
    await prefs.remove(_sessionKey);
  }
}
