import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/local_storage/hive_helper.dart';
import '../../domain/entities/notification_entity.dart';

class NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository(this._apiClient);

  // GET /notifications/list
  Future<List<NotificationEntity>> getNotifications({int page = 1}) async {
    try {
      // 1. API Call
      final response = await _apiClient.dio.get('/notifications/list', queryParameters: {'page': page, 'limit': 20});

      if (response.data['data'] != null && response.data['data']['notifications'] != null) {
        final List data = response.data['data']['notifications'];
        final notifications = data.map((e) => NotificationEntity.fromJson(e)).toList();

        // 2. SAVE TO HIVE (SAFE MODE)
        // Isko try-catch me wrap kiya taaki cache fail hone par bhi UI na ruke
        if (page == 1) {
          try {
            final jsonList = notifications.map((e) => e.toJson()).toList();
            await HiveHelper.cacheNotifications(jsonList);
          } catch (e) {
            debugPrint("Cache Save Failed: $e"); // Log error but continue
          }
        }

        return notifications;
      }
      return [];
    } catch (e) {
      debugPrint("Notification API Error: $e");
      // 3. Fallback to Cache if API fails
      if (page == 1) {
        try {
          final cached = HiveHelper.getCachedNotifications();
          if (cached.isNotEmpty) {
            return cached.map((e) => NotificationEntity.fromJson(e)).toList();
          }
        } catch (cacheError) {
          debugPrint("Cache Retrieval Failed: $cacheError");
        }
      }
      rethrow;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _apiClient.dio.put('/notifications/read/$notificationId');
    } catch (e) {
      debugPrint("Mark Read Failed: $e");
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _apiClient.dio.get('/notifications/unread-count');
      return response.data['data']['unreadCount'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> followBack(String targetUserId) async {
    await _apiClient.dio.post('/follow/follow-back/$targetUserId');
  }
}