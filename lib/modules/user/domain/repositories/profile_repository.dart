import 'dart:io';
import '../../../feed/domain/entities/post_entity.dart';
import '../entities/user_entity.dart';

abstract class ProfileRepository {
  Future<UserEntity?> getCachedUserProfile(String userId);
  Future<UserEntity> getRemoteUserProfile(String userId);
  Future<UserEntity> getMyProfile();

  Future<void> updateProfile({String? bio, File? image});
  Future<void> followUser(String userId);
  Future<void> unfollowUser(String userId);

  Future<void> blockUser(String userId);
  Future<void> unblockUser(String userId);
  Future<void> reportUser(String userId, String reason);

  Future<List<UserEntity>> searchUsers(String query);
  Future<List<PostEntity>> getUserPosts(String userId);

  // --- NEW: Fetch Single Post Details ---
  Future<PostEntity> getPostDetails(String postId);

  // Legacy
  Future<UserEntity> getUserProfile(String userId);
}