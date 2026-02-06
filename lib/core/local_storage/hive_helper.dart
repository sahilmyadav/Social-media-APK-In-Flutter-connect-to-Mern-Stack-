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
}