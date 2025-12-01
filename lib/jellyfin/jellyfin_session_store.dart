import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'jellyfin_session.dart';

class JellyfinSessionStore {
  static const _boxName = 'nautune_session';
  static const _sessionKey = 'session';

  Future<Box> _box() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        debugPrint('📦 JellyfinSessionStore: Opening Hive box: $_boxName');
        final box = await Hive.openBox(_boxName);
        debugPrint('✅ JellyfinSessionStore: Box opened successfully');
        return box;
      }
      return Hive.box(_boxName);
    } catch (e) {
      debugPrint('❌ JellyfinSessionStore: Failed to open box: $e');
      rethrow;
    }
  }

  Future<JellyfinSession?> load() async {
    try {
      final box = await _box();
      final raw = box.get(_sessionKey);
      
      if (raw == null) {
        debugPrint('📭 JellyfinSessionStore: No session found in storage');
        return null;
      }

      debugPrint('📥 JellyfinSessionStore: Loading session from storage');

      // Hive stores data as Map<dynamic, dynamic> which needs to be converted
      // Support both Map (from Hive) and String (legacy from SharedPreferences)
      final Map<String, dynamic> json;
      if (raw is Map) {
        // Convert Map<dynamic, dynamic> to Map<String, dynamic>
        json = raw.map((key, value) {
          // Recursively convert nested maps
          if (value is Map) {
            return MapEntry(
              key.toString(),
              value.map((k, v) => MapEntry(k.toString(), v)),
            );
          }
          return MapEntry(key.toString(), value);
        });
      } else if (raw is String) {
        json = jsonDecode(raw) as Map<String, dynamic>;
      } else {
        debugPrint('⚠️ JellyfinSessionStore: Invalid session data type: ${raw.runtimeType}');
        return null;
      }
      
      final session = JellyfinSession.fromJson(json);
      debugPrint('✅ JellyfinSessionStore: Session loaded for ${session.username}');
      return session;
    } catch (e) {
      debugPrint('❌ JellyfinSessionStore: Failed to load session: $e');
      try {
        final box = await _box();
        await box.delete(_sessionKey);
      } catch (_) {}
      return null;
    }
  }

  Future<void> save(JellyfinSession session) async {
    try {
      debugPrint('💾 JellyfinSessionStore: Saving session for ${session.username}');
      final box = await _box();
      // Store as Map for better Hive performance/usage
      await box.put(_sessionKey, session.toJson());
      debugPrint('✅ JellyfinSessionStore: Session saved successfully');
    } catch (e) {
      debugPrint('❌ JellyfinSessionStore: Failed to save session: $e');
      rethrow;
    }
  }

  Future<void> clear() async {
    try {
      debugPrint('🗑️ JellyfinSessionStore: Clearing session');
      final box = await _box();
      await box.delete(_sessionKey);
      debugPrint('✅ JellyfinSessionStore: Session cleared');
    } catch (e) {
      debugPrint('❌ JellyfinSessionStore: Failed to clear session: $e');
      rethrow;
    }
  }
}
