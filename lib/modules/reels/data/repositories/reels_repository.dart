import 'package:dio/dio.dart';
import '../../../../core/local_storage/hive_helper.dart';
import '../../../../core/network/api_client.dart';
import '../../../feed/domain/entities/comment_entity.dart';
import '../../domain/entities/reel_entity.dart';

class ReelsRepository {
  final ApiClient _apiClient;

  ReelsRepository(this._apiClient);

  // --- REEL FEED WITH SERVER SYNC & HIVE ---
  Future<List<ReelEntity>> getReelsFeed({int page = 1}) async {
    // 1. Try to load from Cache first (only if page 1, to give instant UI)
    if (page == 1) {
      final cachedData = HiveHelper.getCachedReels();
      if (cachedData.isNotEmpty) {
        // Return cached data immediately while we fetch fresh data
        // Note: In a real app you might stream this, but for now we return cache if avail
        // or just proceed. To keep it simple: We return fresh if possible, else cache.
        // Actually, let's just use cache as fallback or initial load in Bloc.
      }
    }

    try {
      final feedResponse = await _apiClient.dio.get('/feed/reels', queryParameters: {'page': page, 'limit': 10});

      List<ReelEntity> reels = [];
      if (feedResponse.data['data'] != null && feedResponse.data['data']['reels'] != null) {
        final List data = feedResponse.data['data']['reels'];
        reels = data.map((e) => ReelEntity.fromJson(e)).toList();
      }

      // Sync Saved State (Safe Fail)
      try {
        final savedResponse = await _apiClient.dio.get('/reel/saved', queryParameters: {'limit': 100});
        Set<String> savedReelIds = {};
        if (savedResponse.data['data'] != null && savedResponse.data['data']['reels'] != null) {
          final List savedData = savedResponse.data['data']['reels'];
          savedReelIds = savedData.map((e) => e['_id'].toString()).toSet();
        }
        reels = reels.map((reel) {
          if (savedReelIds.contains(reel.id)) {
            return reel.copyWith(isSaved: true);
          }
          return reel;
        }).toList();
      } catch (e) {
        // Continue even if sync fails
      }

      // 2. Save Fresh Data to Cache (Only Page 1 to avoid overwriting feed with pagination data)
      if (page == 1 && reels.isNotEmpty) {
        // Convert Entities to JSON for Hive
        final reelsJson = reels.map((r) => r.toJson()).toList();
        await HiveHelper.cacheReels(reelsJson);
      }

      return reels;
    } catch (e) {
      // 3. Fallback to Cache on Error
      if (page == 1) {
        final cachedData = HiveHelper.getCachedReels();
        if (cachedData.isNotEmpty) {
          return cachedData.map((e) => ReelEntity.fromJson(e)).toList();
        }
      }
      throw Exception("Failed to load reels feed");
    }
  }

  // --- NEW: Update Single Reel in Cache ---
  Future<void> updateReelInCache(ReelEntity updatedReel) async {
    final cachedData = HiveHelper.getCachedReels();
    if (cachedData.isEmpty) return;

    final List<dynamic> updatedList = cachedData.map((item) {
      // item is a Map<String, dynamic>
      if (item['_id'] == updatedReel.id) {
        return updatedReel.toJson();
      }
      return item;
    }).toList();

    await HiveHelper.cacheReels(updatedList);
  }

  // --- ACTIONS ---
  Future<void> toggleLikeReel(String reelId) async {
    await _apiClient.dio.post('/reel/toggle-like/$reelId');
  }

  Future<void> saveReel(String reelId) async {
    await _apiClient.dio.post('/reel/save/$reelId');
  }

  Future<void> unsaveReel(String reelId) async {
    await _apiClient.dio.delete('/reel/unsave/$reelId');
  }

  Future<void> followUser(String userId) async {
    await _apiClient.dio.post('/users/follow/$userId');
  }

  Future<void> unfollowUser(String userId) async {
    await _apiClient.dio.post('/users/unfollow/$userId');
  }

  // --- COMMENTS ---

  Future<List<CommentEntity>> getComments(String reelId) async {
    // Return Cache Immediately
    final cachedData = HiveHelper.getCachedComments(reelId);

    try {
      final response = await _apiClient.dio.get('/reel/comments/$reelId', queryParameters: {'limit': 50});

      if (response.data['data'] != null && response.data['data']['comments'] != null) {
        final List data = response.data['data']['comments'];
        await HiveHelper.cacheComments(reelId, data); // Update Cache
        return data.map((e) => CommentEntity.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (cachedData.isNotEmpty) {
        return cachedData.map((e) => CommentEntity.fromJson(e)).toList();
      }
      rethrow;
    }
  }

  Future<CommentEntity> addComment(String reelId, String text) async {
    final response = await _apiClient.dio.post(
      '/reel/comment/$reelId',
      data: {'text': text}, // Changed to 'text' to match server requirement
    );
    return CommentEntity.fromJson(response.data['data']);
  }

  // --- MISSING METHODS ADDED BELOW ---

  Future<void> toggleCommentLike(String commentId, bool isLiked) async {
    // API is a toggle endpoint
    await _apiClient.dio.post('/comment/like/$commentId');
  }

  Future<CommentEntity> replyToComment(String commentId, String text) async {
    final response = await _apiClient.dio.post(
      '/comment/reply/$commentId',
      data: {'text': text}, // Changed to 'text' to match server requirement
    );
    if (response.data['data'] != null) {
      return CommentEntity.fromJson(response.data['data']);
    }
    throw Exception("Failed to reply");
  }

  Future<List<CommentEntity>> getCommentReplies(String commentId) async {
    // Assuming standard endpoint structure
    final response = await _apiClient.dio.get('/comment/replies/$commentId');
    if (response.data['data'] != null) {
      final data = response.data['data'];
      if (data is List) {
        return data.map((e) => CommentEntity.fromJson(e)).toList();
      } else if (data['replies'] is List) {
        return (data['replies'] as List).map((e) => CommentEntity.fromJson(e)).toList();
      }
    }
    return [];
  }
}