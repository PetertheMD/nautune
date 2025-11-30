import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import 'jellyfin_session.dart';

class JellyfinSessionStore {
  static const _boxName = 'nautune_session';
  static const _sessionKey = 'session';

  Future<Box> _box() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  Future<JellyfinSession?> load() async {
    final box = await _box();
    final raw = box.get(_sessionKey);
    if (raw == null) {
      return null;
    }

    try {
      // Hive might store it as a Map directly if we put it as Map, 
      // but keeping JSON string encoding for compatibility with existing logic structure 
      // or simple migration is fine. 
      // However, `save` below will store Map. Let's support both for robustness or just Map.
      // Ideally, we should migrate data if it was in SharedPreferences? 
      // For now, let's stick to the requested format. 
      // If raw is Map, use it. If String, decode it.
      final Map<String, dynamic> json;
      if (raw is Map) {
        json = Map<String, dynamic>.from(raw);
      } else if (raw is String) {
        json = jsonDecode(raw) as Map<String, dynamic>;
      } else {
        return null;
      }
      
      return JellyfinSession.fromJson(json);
    } catch (_) {
      await box.delete(_sessionKey);
      return null;
    }
  }

  Future<void> save(JellyfinSession session) async {
    final box = await _box();
    // Store as Map for better Hive performance/usage
    await box.put(_sessionKey, session.toJson());
  }

  Future<void> clear() async {
    final box = await _box();
    await box.delete(_sessionKey);
  }
}
