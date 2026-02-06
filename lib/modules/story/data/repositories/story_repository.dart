import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/story_entity.dart';

class StoryRepository {
  final ApiClient _apiClient;

  StoryRepository(this._apiClient);

  // GET /story/feed
  Future<List<StoryFeedEntity>> getStoryFeed() async {
    try {
      final response = await _apiClient.dio.get('/story/feed');
      final List data = response.data['data'];
      return data.map((e) => StoryFeedEntity.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // POST /story/view/:storyId
  Future<void> markStoryViewed(String storyId) async {
    await _apiClient.dio.post('/story/view/$storyId');
  }

  // POST /story/upload
  Future<void> uploadStory(File file, {String caption = ""}) async {
    String fileName = file.path.split('/').last;
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(file.path, filename: fileName),
      "caption": caption,
      "type": "image", // Defaulting to image for MVP
      "duration": 5 // Default 5s
    });
    await _apiClient.dio.post('/story/upload', data: formData);
  }
}