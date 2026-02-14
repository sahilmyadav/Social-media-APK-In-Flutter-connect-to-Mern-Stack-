import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/live_stream_entity.dart';

class LiveRepository {
  final ApiClient _apiClient;

  LiveRepository(this._apiClient);

  // POST /live/create
  Future<LiveStreamEntity> createLiveStream({
    required String title,
    String? description,
    String? thumbnailPath,
  }) async {
    final Map<String, dynamic> map = {"title": title};
    if (description != null && description.isNotEmpty) {
      map["description"] = description;
    }
    map["visibility"] = "public"; // Explicitly send visibility

    if (thumbnailPath != null) {
      map["thumbnail"] = await MultipartFile.fromFile(thumbnailPath);
    }

    final formData = FormData.fromMap(map);

    final response = await _apiClient.dio.post('/live/create', data: formData);
    // Debug print for create
    debugPrint("🚀 Create Stream Response: ${response.data}");
    return LiveStreamEntity.fromJson(response.data['data']);
  }

  // POST /live/start/:streamId
  Future<void> startLiveStream(String streamId) async {
    await _apiClient.dio.post('/live/start/$streamId', data: {});
  }

  // POST /live/end/:streamId
  Future<void> endLiveStream(String streamId) async {
    await _apiClient.dio.post('/live/end/$streamId', data: {});
  }

  // GET /live/details/:streamId
  Future<LiveStreamEntity> getStreamDetails(String streamId) async {
    final response = await _apiClient.dio.get('/live/details/$streamId');
    return LiveStreamEntity.fromJson(response.data['data']);
  }

  // GET /live/active
  Future<List<LiveStreamEntity>> getActiveStreams() async {
    final response = await _apiClient.dio.get('/live/active');
    final List data = response.data['data'] ?? [];
    return data.map((e) => LiveStreamEntity.fromJson(e)).toList();
  }

  // GET /live/all
  Future<List<LiveStreamEntity>> getAllStreams({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.dio.get(
      '/live/all',
      queryParameters: {"page": page, "limit": limit},
    );
    final List data = response.data['data']['streams'] ?? [];
    return data.map((e) => LiveStreamEntity.fromJson(e)).toList();
  }

  // POST /live/join/:streamId
  Future<LiveStreamEntity> joinLiveStream(String streamId) async {
    final response =
        await _apiClient.dio.post('/live/join/$streamId', data: {});

    // Debug print to see if token is returned
    debugPrint("🚀 Join Response Data: ${response.data}");

    // The join response might contain updated viewer count or playbackUrl
    // To keep type safety, let's fetch details again or construct what we can.
    return getStreamDetails(streamId);
  }

  // POST /live/leave/:streamId
  Future<void> leaveLiveStream(String streamId) async {
    await _apiClient.dio.post('/live/leave/$streamId', data: {});
  }

  // GET /live/viewers/:streamId
  Future<List<dynamic>> getViewers(String streamId) async {
    final response = await _apiClient.dio.get('/live/viewers/$streamId');
    return response.data['data'] ?? [];
  }

  // POST /live/comment/:streamId
  Future<void> sendComment(String streamId, String content) async {
    await _apiClient.dio.post(
      '/live/comment/$streamId',
      data: {"text": content}, // Changed 'content' to 'text' as per docs
    );
  }

  // GET /live/comments/:streamId
  Future<List<dynamic>> getComments(String streamId) async {
    final response = await _apiClient.dio.get('/live/comments/$streamId');
    return response.data['data'] ?? [];
  }

  // GET /live/user/:userId
  Future<List<LiveStreamEntity>> getUserLiveStreams(String userId) async {
    final response = await _apiClient.dio.get('/live/user/$userId');
    final List data = response.data['data'] ?? [];
    return data.map((e) => LiveStreamEntity.fromJson(e)).toList();
  }

  // DELETE /live/delete/:streamId
  Future<void> deleteLiveStream(String streamId) async {
    await _apiClient.dio.delete('/live/delete/$streamId');
  }
}
