import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/story_entity.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';

class StoryRepository {
  final ApiClient _apiClient;

  StoryRepository(this._apiClient);

  // GET /story/feed
  Future<List<StoryFeedEntity>> getStoryFeed() async {
    try {
      final response = await _apiClient.dio.get('/story/feed');
      final Map<String, dynamic> data = response.data['data'];
      final List stories = data['stories'] ?? [];
      return stories.map((e) => StoryFeedEntity.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error fetching story feed: $e");
      return [];
    }
  }

  // POST /story/view/:storyId
  Future<void> markStoryViewed(String storyId) async {
    await _apiClient.dio.post('/story/view/$storyId');
  }

  // POST /story/upload
  Future<void> uploadStory(File file,
      {String caption = "", int duration = 5}) async {
    try {
      String fileName = file.path.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(file.path, filename: fileName),
        "caption": caption,
        "duration": duration
      });
      debugPrint("Uploading story... Duration: $duration");
      await _apiClient.dio.post('/story/upload', data: formData);
      debugPrint("Story uploaded successfully");
    } catch (e) {
      debugPrint("Error uploading story: $e");
      rethrow;
    }
  }

  // DELETE /story/delete/:storyId
  Future<void> deleteStory(String storyId) async {
    await _apiClient.dio.delete('/story/delete/$storyId');
  }

  // GET /story/user/:userId
  Future<List<StoryItemEntity>> getUserStories(String userId) async {
    try {
      final response = await _apiClient.dio.get('/story/user/$userId');
      final Map<String, dynamic> data = response.data['data'];
      final List stories = data['stories'] ?? [];
      return stories.map((e) => StoryItemEntity.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // GET /story/viewers/:storyId
  Future<List<UserEntity>> getStoryViewers(String storyId) async {
    try {
      final response = await _apiClient.dio.get('/story/viewers/$storyId');
      final List data = response.data['data'];
      return data.map((e) => UserEntity.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }
}
