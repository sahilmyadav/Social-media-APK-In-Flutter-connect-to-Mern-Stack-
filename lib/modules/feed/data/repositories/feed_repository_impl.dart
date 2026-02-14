import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/local_storage/hive_helper.dart';
import '../../../../core/utils/pretty_logger.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/entities/comment_entity.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';

class FeedRepositoryImpl {
  final ApiClient _apiClient;

  FeedRepositoryImpl(this._apiClient);

  // --- HELPER: BLACKLIST LOGIC (Local Hide) ---
  Future<void> _blacklistPostLocally(String postId) async {
    try {
      final box = await Hive.openBox('hidden_posts_box');
      await box.put(postId, true);
      debugPrint("[BLACKLIST] Post $postId added to local hidden list.");
    } catch (e) {
      debugPrint("[BLACKLIST] Failed to hide post locally: $e");
    }
  }

  Future<List<String>> _getBlacklistedPostIds() async {
    try {
      if (!Hive.isBoxOpen('hidden_posts_box')) {
        await Hive.openBox('hidden_posts_box');
      }
      final box = Hive.box('hidden_posts_box');
      return box.keys.map((k) => k.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  // --- USER LOGIC ---
  Future<UserEntity?> getCurrentUser() async {
    try {
      final response = await _apiClient.dio.get('/users/current-user');
      if (response.statusCode == 200 && response.data['data'] != null) {
        final Map<String, dynamic> userData = response.data['data'];
        if (userData['profilePicture'] != null &&
            userData['profilePicture'].toString().startsWith('/')) {
          userData['profilePicture'] =
              "https://clikkme.in${userData['profilePicture']}";
        }
        return UserEntity.fromJson(userData);
      }
    } catch (e) {
      debugPrint("[DEBUG] Repo: Get Current User Error: $e");
    }
    return null;
  }

  // --- FEED LOGIC ---
  List<PostEntity> getCachedFeed() {
    try {
      final cachedData = HiveHelper.getCachedFeed();
      if (Hive.isBoxOpen('hidden_posts_box')) {
        final hiddenBox = Hive.box('hidden_posts_box');
        cachedData.removeWhere((post) => hiddenBox.containsKey(post['_id']));
      }

      if (cachedData.isNotEmpty) {
        return cachedData.map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          return PostEntity.fromJson(map);
        }).toList();
      }
    } catch (e) {
      debugPrint("[DEBUG] Repo: Cache Fetch Error: $e");
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // NEW: DEDICATED API FETCHERS (The Fix for Reinstall Issue)
  // ---------------------------------------------------------------------------

  // 1. Fetch User's Saved Post IDs
  // API Reference: GET /post/user-saved-posts
  Future<List<String>> _getSavedPostIds() async {
    try {
      final response = await _apiClient.dio
          .get('/post/user-saved-posts', queryParameters: {'limit': 100});

      if (response.data['data'] == null) return [];

      // --- FIX: Handle Direct List vs Nested Object ---
      // Your log showed 'data' is a List directly: [{"_id":...}]
      dynamic rawData = response.data['data'];
      List posts = [];

      if (rawData is List) {
        posts = rawData; // Direct list (Based on your logs)
      } else if (rawData is Map && rawData['posts'] != null) {
        posts = rawData['posts']; // Fallback for nested structure
      }

      // Extract IDs
      final ids = posts.map((e) => e['_id'].toString()).toList();
      print(
          '\x1B[33m[FIX DEBUG] Found ${ids.length} Saved Posts via Dedicated API\x1B[0m');
      return ids;
    } catch (e) {
      // Changed to print full error for debugging
      print('\x1B[31m[FIX ERROR] Failed to fetch saved posts list: $e\x1B[0m');
      return [];
    }
  }

  // 2. Fetch User's Following IDs
  // API Reference: GET /follow/following/:userId
  Future<List<String>> _getFollowingIds(String currentUserId) async {
    try {
      final response = await _apiClient.dio.get(
          '/follow/following/$currentUserId',
          queryParameters: {'limit': 100});

      if (response.data['data'] == null) return [];
      // Following API returns nested object: data: { "following": [...] }
      final List users = response.data['data']['following'] ?? [];

      final ids = users.map((e) => e['_id'].toString()).toList();
      print(
          '\x1B[33m[FIX DEBUG] Found ${ids.length} Followed Users via Dedicated API\x1B[0m');
      return ids;
    } catch (e) {
      print('\x1B[31m[FIX ERROR] Failed to fetch following list: $e\x1B[0m');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATED REMOTE FEED (With Logic to Fix Missing Statuses)
  // ---------------------------------------------------------------------------
  Future<List<PostEntity>> getRemoteFeed({int page = 1}) async {
    try {
      // Step 1: We need the Current User ID to fetch the "Following List"
      String currentUserId = '';
      if (page == 1) {
        try {
          final userRes = await _apiClient.dio.get('/users/current-user');
          currentUserId = userRes.data['data']?['_id']?.toString() ?? '';
        } catch (e) {
          debugPrint("[DEBUG] Could not get current user ID: $e");
        }
      }

      // Step 2: Fetch Data in Parallel (Feed + Fix Lists)
      print(
          '\x1B[34m[FEED] Fetching Page $page... (Syncing Save/Follow state)\x1B[0m');

      final results = await Future.wait([
        // 0. The Feed
        _apiClient.dio
            .get('/feed/home', queryParameters: {'page': page, 'limit': 10}),

        // 1. Saved IDs (Only on page 1)
        (page == 1) ? _getSavedPostIds() : Future.value(<String>[]),

        // 2. Following IDs (Only on page 1 & if we have user ID)
        (page == 1 && currentUserId.isNotEmpty)
            ? _getFollowingIds(currentUserId)
            : Future.value(<String>[]),
      ]);

      final feedResponse = results[0] as Response;
      final savedIds = results[1] as List<String>;
      final followingIds = results[2] as List<String>;

      if (feedResponse.data['data'] == null) return [];
      List<dynamic> apiData = feedResponse.data['data']['posts'] ?? [];

      // Step 3: MERGE Logic
      final List<PostEntity> remotePosts = apiData.map((e) {
        final post = PostEntity.fromJson(e);

        // 1. FIX SAVED STATUS
        bool realIsSaved = post.isSaved;
        if (savedIds.isNotEmpty) {
          if (savedIds.contains(post.id)) {
            realIsSaved = true; // FORCE TRUE if in list
          }
        }

        // 2. FIX FOLLOWING STATUS
        bool realIsFollowing = post.user.isFollowing ?? false;
        if (followingIds.isNotEmpty) {
          if (followingIds.contains(post.user.id)) {
            realIsFollowing = true; // FORCE TRUE if in list
          }
        }

        return post.copyWith(
          isSaved: realIsSaved,
          user: post.user.copyWith(isFollowing: realIsFollowing),
        );
      }).toList();

      // Step 4: Cache the CORRECTED data
      if (page == 1) {
        // Create patched JSON for Hive so offline mode works correctly too
        final List<Map<String, dynamic>> correctedJsonList =
            remotePosts.map((p) {
          final rawObj = apiData.firstWhere(
              (raw) => (raw['_id'] ?? raw['id']) == p.id,
              orElse: () => {});
          if (rawObj is Map<String, dynamic>) {
            rawObj['isSaved'] = p.isSaved;
            if (rawObj['user_id'] is Map) {
              rawObj['user_id']['isFollowing'] = p.user.isFollowing;
            } else if (rawObj['user'] is Map) {
              rawObj['user']['isFollowing'] = p.user.isFollowing;
            }
            return rawObj;
          }
          return <String, dynamic>{};
        }).toList();

        await HiveHelper.cacheFeed(correctedJsonList);
        print(
            '\x1B[32m[CACHE] Feed synced with corrected Save/Follow states.\x1B[0m');
      }

      return remotePosts;
    } catch (e) {
      debugPrint("[DEBUG] Repo: Feed Fetch Error: $e");
      throw Exception("Failed to sync feed with server");
    }
  }

// ... inside FeedRepositoryImpl class ...

// ... imports

  // --- UPDATED: Get Follow Suggestions ---
  Future<List<UserEntity>> getFollowSuggestions() async {
    const String endpoint = '/follow/suggestions';
    try {
      final response =
          await _apiClient.dio.get(endpoint, queryParameters: {'limit': 10});

      if (response.data['data'] == null) return [];

      dynamic rawData = response.data['data'];
      List listData = [];

      // Handle Direct List vs Nested Object
      if (rawData is List) {
        listData = rawData;
      } else if (rawData is Map && rawData['suggestions'] != null) {
        listData = rawData['suggestions'];
      }

      return listData.map((e) {
        final map = Map<String, dynamic>.from(e);

        // 1. FIX MISSING IMAGES: Map 'avatar'/'profileImage' to 'profilePicture'
        if (map['profilePicture'] == null) {
          if (map['profileImage'] != null)
            map['profilePicture'] = map['profileImage'];
          else if (map['avatar'] != null) map['profilePicture'] = map['avatar'];
        }

        // 2. FIX URL: Ensure it has the domain
        if (map['profilePicture'] != null &&
            map['profilePicture'].toString().startsWith('/')) {
          map['profilePicture'] = "https://clikkme.in${map['profilePicture']}";
        }

        return UserEntity.fromJson(map);
      }).toList();
    } catch (e) {
      print('\x1B[31m[SUGGESTIONS ERROR] $e\x1B[0m');
      return [];
    }
  }

// ... rest of the file
  Future<void> followUser(String targetUserId) async {
    await _apiClient.dio.post('/follow/request/$targetUserId');
  }

  Future<void> unfollowUser(String targetUserId) async {
    await _apiClient.dio.delete('/follow/unfollow/$targetUserId');
  }

  // --- POST ACTIONS ---
  Future<void> likePost(String postId) async {
    await _apiClient.dio.post('/post/like/$postId');
  }

  Future<void> unlikePost(String postId) async {
    await _apiClient.dio.delete('/post/unlike/$postId');
  }

  Future<void> savePost(String postId) async {
    try {
      await _apiClient.dio.post('/post/save/$postId');
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 400) return;
      rethrow;
    }
  }

  Future<void> unsavePost(String postId) async {
    await _apiClient.dio.delete('/post/unsave/$postId');
  }

  Future<void> deletePost(String postId) async {
    await _apiClient.dio.delete('/post/delete/$postId');
  }

  Future<void> reportPost(
      String postId, String reason, String description) async {
    final String fullPath = '/post/report/$postId';
    final Map<String, dynamic> body = {
      "reason": reason,
      "description": description
    };
    PrettyLogger.logRequest('POST', fullPath, body: body);
    try {
      final response = await _apiClient.dio.post(fullPath, data: body);
      PrettyLogger.logSuccess(fullPath, response.data);
      await _blacklistPostLocally(postId);
    } catch (e) {
      if (e is DioException) {
        PrettyLogger.logError(fullPath, "Report Failed",
            responseBody: e.response?.data);
      }
      rethrow;
    }
  }

  // --- CACHE UPDATE HELPERS ---
  Future<void> updatePostInCache(String postId,
      {bool? isSaved, bool? isLiked}) async {
    try {
      final box = await Hive.openBox('feed_box');
      final List rawFeed = box.get('home_feed', defaultValue: []);
      final int index = rawFeed.indexWhere((p) => p['_id'] == postId);

      if (index != -1) {
        final Map<String, dynamic> postMap =
            Map<String, dynamic>.from(rawFeed[index] as Map);
        if (isSaved != null) postMap['isSaved'] = isSaved;
        if (isLiked != null) {
          postMap['isLiked'] = isLiked;
          int likes = int.tryParse(postMap['likes_count'].toString()) ?? 0;
          postMap['likes_count'] =
              isLiked ? likes + 1 : (likes > 0 ? likes - 1 : 0);
        }
        rawFeed[index] = postMap;
        await box.put('home_feed', rawFeed);
      }
    } catch (e) {
      debugPrint("[CACHE] Failed to update post cache: $e");
    }
  }

  Future<void> updateFollowStatusInCache(
      String userId, bool isFollowing) async {
    try {
      final box = await Hive.openBox('feed_box');
      final List rawFeed = box.get('home_feed', defaultValue: []);
      bool changed = false;

      for (int i = 0; i < rawFeed.length; i++) {
        final Map<String, dynamic> postMap =
            Map<String, dynamic>.from(rawFeed[i] as Map);
        dynamic userObj = postMap['user'] ?? postMap['user_id'];

        if (userObj != null && userObj is Map) {
          if (userObj['_id'] == userId) {
            final Map<String, dynamic> mutableUser =
                Map<String, dynamic>.from(userObj);
            mutableUser['isFollowing'] = isFollowing;

            if (postMap.containsKey('user')) postMap['user'] = mutableUser;
            if (postMap.containsKey('user_id'))
              postMap['user_id'] = mutableUser;

            rawFeed[i] = postMap;
            changed = true;
          }
        }
      }

      if (changed) {
        await box.put('home_feed', rawFeed);
        debugPrint(
            "[CACHE] Updated follow status for user $userId to $isFollowing");
      }
    } catch (e) {
      debugPrint("[CACHE] Failed to update follow cache: $e");
    }
  }

  // --- COMMENTS ---
  List<CommentEntity> getCachedComments(String postId) {
    if (!Hive.isBoxOpen('comments_cache')) return [];
    final box = Hive.box('comments_cache');
    final cachedData = box.get(postId, defaultValue: []);
    if (cachedData is List && cachedData.isNotEmpty) {
      return cachedData
          .map((e) =>
              CommentEntity.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  // 1. Get Top-Level Comments
  Future<List<CommentEntity>> getRemoteComments(String postId) async {
    final String fullPath = '/post/comments/$postId';
    // PrettyLogger.logRequest('GET', fullPath); // Optional logging

    try {
      final response = await _apiClient.dio.get(fullPath);
      List rawData = [];

      if (response.data['data'] != null) {
        final dataObj = response.data['data'];
        if (dataObj['comments'] is List) {
          rawData = dataObj['comments'];
        }
      }

      // Cache logic (Optional: Save top-level comments only)
      final box = await Hive.openBox('comments_cache');
      await box.put(postId, rawData);

      return rawData.map((e) => CommentEntity.fromJson(e)).toList();
    } catch (e) {
      throw Exception("Failed to load comments");
    }
  }

  // 2. NEW: Get Replies for a Comment
  //// API: GET /comment/replies/:commentId [cite: 1668]
  Future<List<CommentEntity>> getCommentReplies(String commentId) async {
    final String fullPath = '/comment/replies/$commentId';
    try {
      final response = await _apiClient.dio.get(fullPath);
      List rawData = [];

      if (response.data['data'] != null &&
          response.data['data']['replies'] is List) {
        rawData = response.data['data']['replies'];
      }

      return rawData.map((e) => CommentEntity.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Failed to load replies: $e");
      return [];
    }
  }

  // 3. Reply to Comment
// 3. Reply to Comment (FIXED 400 ERROR)
  Future<CommentEntity> replyToComment(String commentId, String text) async {
    final String fullPath = '/comment/reply/$commentId';

    // FIX: Server requires 'text' key. Sending both to be safe.
    final Map<String, dynamic> body = {"text": text, "content": text};

    PrettyLogger.logRequest('POST', fullPath, body: body);

    try {
      final response = await _apiClient.dio.post(fullPath,
          data: body, options: Options(contentType: Headers.jsonContentType));
      PrettyLogger.logSuccess(fullPath, response.data);
      return CommentEntity.fromJson(response.data['data']);
    } catch (e) {
      if (e is DioException) {
        PrettyLogger.logError(fullPath, "Reply Failed",
            responseBody: e.response?.data);
      }
      throw Exception("Failed to reply");
    }
  }

  Future<CommentEntity> addComment(String postId, String text) async {
    final String fullPath = '/post/comment/$postId';
    final Map<String, dynamic> body = {"text": text, "content": text};

    PrettyLogger.logRequest('POST', fullPath, body: body);

    try {
      final response = await _apiClient.dio.post(fullPath,
          data: body, options: Options(contentType: Headers.jsonContentType));
      PrettyLogger.logSuccess(fullPath, response.data);
      return CommentEntity.fromJson(response.data['data']);
    } catch (e) {
      if (e is DioException) {
        PrettyLogger.logError(fullPath, "Post Comment Failed",
            responseBody: e.response?.data);
      }
      throw Exception("Failed to post comment");
    }
  }

  Future<void> likeComment(String commentId) async {
    final String fullPath = '/comment/like/$commentId';
    PrettyLogger.logRequest('POST', fullPath);
    try {
      await _apiClient.dio.post(fullPath);
      print('\x1B[32m[SUCCESS] Comment Liked\x1B[0m');
    } catch (e) {
      print('\x1B[31m[ERROR] Like Comment Failed: $e\x1B[0m');
    }
  }

  Future<void> unlikeComment(String commentId) async {
    final String fullPath = '/comment/unlike/$commentId';
    PrettyLogger.logRequest('DELETE', fullPath);
    try {
      await _apiClient.dio.delete(fullPath);
      print('\x1B[32m[SUCCESS] Comment Unliked\x1B[0m');
    } catch (e) {
      print('\x1B[31m[ERROR] Unlike Comment Failed: $e\x1B[0m');
    }
  }

  Future<void> deleteComment(String commentId) async {
    final String fullPath = '/comment/delete/$commentId';
    PrettyLogger.logRequest('DELETE', fullPath);
    try {
      await _apiClient.dio.delete(fullPath);
      print('\x1B[32m[SUCCESS] Comment Deleted\x1B[0m');
    } catch (e) {
      if (e is DioException) {
        PrettyLogger.logError(fullPath, "Delete Comment Failed",
            responseBody: e.response?.data);
      }
      throw Exception("Failed to delete comment");
    }
  }
}
