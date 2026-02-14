import 'package:hive_flutter/hive_flutter.dart';

class HiveHelper {
  static const String _feedBoxName = 'feed_box';

  // Initialize Hive (Call this in main.dart)
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_feedBoxName);
  }

  // --- FEED CACHING ---

  // Save Feed safely
  static Future<void> cacheFeed(List data) async {
    final box = await _getBox();
    await box.put('home_feed', data);
  }

  // Get Feed safely
  static List getCachedFeed() {
    if (!Hive.isBoxOpen(_feedBoxName)) return [];
    final box = Hive.box(_feedBoxName);
    return box.get('home_feed', defaultValue: []) ?? [];
  }

  // --- REELS CACHING (NEW) ---

  // Save Reels Feed safely
  static Future<void> cacheReels(List data) async {
    final box = await _getBox();
    await box.put('reels_feed', data);
  }

  // Get Reels Feed safely
  static List getCachedReels() {
    if (!Hive.isBoxOpen(_feedBoxName)) return [];
    final box = Hive.box(_feedBoxName);
    return box.get('reels_feed', defaultValue: []) ?? [];
  }

  // --- COMMENT CACHING ---

  // Save Comments for a specific Reel
  static Future<void> cacheComments(String reelId, List data) async {
    final box = await _getBox();
    await box.put('comments_$reelId', data);
  }

  // Get Cached Comments for a specific Reel
  static List getCachedComments(String reelId) {
    if (!Hive.isBoxOpen(_feedBoxName)) return [];
    final box = Hive.box(_feedBoxName);
    return box.get('comments_$reelId', defaultValue: []) ?? [];
  }

  // --- UTILS ---

  // Helper to ensure box is open
  static Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(_feedBoxName)) {
      return await Hive.openBox(_feedBoxName);
    }
    return Hive.box(_feedBoxName);
  }

  // CRITICAL: Call this once to clear bad data causing crashes
  static Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }

  // --- NOTIFICATION CACHING (NEW) ---
  static Future<void> cacheNotifications(List data) async {
    final box = await _getBox();
    await box.put('notifications_list', data);
  }

  static List getCachedNotifications() {
    if (!Hive.isBoxOpen(_feedBoxName)) return [];
    final box = Hive.box(_feedBoxName);
    return box.get('notifications_list', defaultValue: []) ?? [];
  }

  // --- CHAT THREAD CACHING ---

  /// Cache chat threads for instant loading
  static Future<void> cacheThreads(List data) async {
    final box = await _getBox();
    await box.put('chat_threads', data);
  }

  /// Get cached chat threads
  static List getCachedThreads() {
    if (!Hive.isBoxOpen(_feedBoxName)) return [];
    final box = Hive.box(_feedBoxName);
    return box.get('chat_threads', defaultValue: []) ?? [];
  }

  /// Cache messages for a specific thread
  static Future<void> cacheMessages(String threadId, List data) async {
    final box = await _getBox();
    await box.put('chat_messages_$threadId', data);
  }

  /// Get cached messages for a specific thread
  static List getCachedMessages(String threadId) {
    if (!Hive.isBoxOpen(_feedBoxName)) return [];
    final box = Hive.box(_feedBoxName);
    return box.get('chat_messages_$threadId', defaultValue: []) ?? [];
  }

  // --- FOLLOWED USERS CACHING (NEW) ---
  static Future<void> cacheFollowedUser(String userId) async {
    final box = await _getBox();
    final List<String> current =
        (box.get('followed_users') as List?)?.cast<String>() ?? [];
    if (!current.contains(userId)) {
      current.add(userId);
      await box.put('followed_users', current);
    }
  }

  static Future<void> unfollowUser(String userId) async {
    final box = await _getBox();
    final List<String> current =
        (box.get('followed_users') as List?)?.cast<String>() ?? [];
    if (current.contains(userId)) {
      current.remove(userId);
      await box.put('followed_users', current);
    }
  }

  static List<String> getFollowedUsers() {
    if (!Hive.isBoxOpen(_feedBoxName)) return [];
    final box = Hive.box(_feedBoxName);
    return (box.get('followed_users') as List?)?.cast<String>() ?? [];
  }
}
