import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/network/api_client.dart';

import '../../../feed/domain/entities/post_entity.dart';

import '../../../reels/domain/entities/reel_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ApiClient _apiClient;
  static const String _boxName = 'user_profiles_cache';

  ProfileRepositoryImpl(this._apiClient);

  Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  UserEntity _mapJsonToEntity(Map<String, dynamic> json) {
    return UserEntity.fromJson(json);
  }

  @override
  Future<UserEntity?> getCachedUserProfile(String userId) async {
    try {
      final box = await _getBox();
      final data = box.get(userId);
      if (data != null) {
        return _mapJsonToEntity(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      debugPrint("⚠️ [CACHE] Error: $e");
    }
    return null;
  }

  @override
  Future<UserEntity> getRemoteUserProfile(String userId) async {
    try {
      List<String> myBlockedIds = [];
      try {
        final myProfileResponse = await _apiClient.dio.get('/users/current-user');
        final myData = myProfileResponse.data['data'];
        if (myData['blockedUsers'] != null) {
          myBlockedIds = List<String>.from(myData['blockedUsers'].map((e) => e.toString()));
        }
      } catch (e) {
        debugPrint("⚠️ Could not verify block status: $e");
      }

      if (myBlockedIds.contains(userId)) {
        debugPrint("🚫 User $userId is blocked. Fetching from Blocked List.");
        final blockedListResponse = await _apiClient.dio.get('/users/blocked-list');
        final Map<String, dynamic> responseData = blockedListResponse.data['data'];
        final List blockedUsers = responseData['blockedUsers'] ?? [];

        final blockedUserJson = blockedUsers.firstWhere((u) => u['_id'] == userId, orElse: () => null);

        if (blockedUserJson != null) {
          return _mapJsonToEntity(blockedUserJson).copyWith(isBlocked: true);
        } else {
          return UserEntity(id: userId, username: "Blocked User", firstName: "User", lastName: "Blocked", isBlocked: true);
        }
      }

      debugPrint("🔍 API CALL: [GET] /users/profile/$userId");
      final response = await _apiClient.dio.get('/users/profile/$userId');
      final targetUser = _mapJsonToEntity(response.data['data']);

      final box = await _getBox();
      await box.put(userId, response.data['data']);

      return targetUser;

    } catch (e) {
      debugPrint("❌ API ERROR (getRemoteUserProfile): $e");
      rethrow;
    }
  }

  // --- NEW: Fetch Single Post Details ---
  @override
  Future<PostEntity> getPostDetails(String postId) async {
    try {
      debugPrint("🔍 API CALL: [GET] /post/details/$postId");
      final response = await _apiClient.dio.get('/post/details/$postId');

      if (response.statusCode == 200 && response.data['data'] != null) {
        return PostEntity.fromJson(response.data['data']);
      } else {
        throw Exception("Post not found");
      }
    } catch (e) {
      debugPrint("❌ API ERROR (getPostDetails): $e");
      rethrow;
    }
  }

  @override
  Future<UserEntity> getMyProfile() async {
    final response = await _apiClient.dio.get('/users/current-user');
    return _mapJsonToEntity(response.data['data']);
  }

  @override
  Future<void> followUser(String userId) async {
    await _apiClient.dio.post('/follow/request/$userId');
  }

  @override
  Future<void> unfollowUser(String userId) async {
    await _apiClient.dio.delete('/follow/unfollow/$userId');
  }

  @override
  Future<void> blockUser(String userId) async {
    await _apiClient.dio.post('/users/block/$userId');
  }

  @override
  Future<void> unblockUser(String userId) async {
    await _apiClient.dio.post('/users/unblock/$userId');
  }

  @override
  Future<void> reportUser(String userId, String reason) async {
    debugPrint("⚠️ REPORT MOCKED: [POST] /users/report/$userId Reason: $reason");
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Future<List<UserEntity>> searchUsers(String query) async {
    final response = await _apiClient.dio.get('/search/users', queryParameters: {'q': query});
    final List data = response.data['data'];
    return data.map((e) => _mapJsonToEntity(e)).toList();
  }

  @override
  Future<void> updateProfile({String? bio, File? image}) async {
    if (bio != null) {
      await _apiClient.dio.put('/users/update-profile', data: {'bio': bio});
    }
    if (image != null) {
      String fileName = image.path.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(image.path, filename: fileName),
      });
      await _apiClient.dio.put('/users/update-profile-picture', data: formData);
    }
  }

  @override
  Future<List<PostEntity>> getUserPosts(String userId) async {
    try {
      final String endpoint = '/feed/posts/$userId';
      final response = await _apiClient.dio.get(endpoint);

      if (response.data['data'] != null && response.data['data']['posts'] != null) {
        final List data = response.data['data']['posts'];
        return data.map((json) => PostEntity.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<ReelEntity>> getUserReels(String userId) async {
    try {
      // Updated Endpoint for Reels
      final String endpoint = '/reel/user/$userId';
      final response = await _apiClient.dio.get(endpoint);

      if (response.data['data'] != null && response.data['data']['reels'] != null) {
        final List data = response.data['data']['reels'];
        return data.map((json) => ReelEntity.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("❌ API ERROR (getUserReels): $e");
      return [];
    }
  }

  @override
  Future<UserEntity> getUserProfile(String userId) => getRemoteUserProfile(userId);
}