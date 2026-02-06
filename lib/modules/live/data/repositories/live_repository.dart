import '../../../../core/network/api_client.dart';
import '../../domain/entities/live_stream_entity.dart';

class LiveRepository {
  final ApiClient _apiClient;

  LiveRepository(this._apiClient);

  // POST /live/create
  Future<LiveStreamEntity> createLiveStream(String title) async {
    final response = await _apiClient.dio.post('/live/create', data: {
      "title": title,
      "visibility": "public"
    });
    return LiveStreamEntity.fromJson(response.data['data']);
  }

  // POST /live/start/:streamId
  Future<void> startLiveStream(String streamId) async {
    await _apiClient.dio.post('/live/start/$streamId');
  }

  // POST /live/end/:streamId
  Future<void> endLiveStream(String streamId) async {
    await _apiClient.dio.post('/live/end/$streamId');
  }

  // POST /live/join/:streamId
  Future<LiveStreamEntity> joinLiveStream(String streamId) async {
    final response = await _apiClient.dio.post('/live/join/$streamId');
    // Assuming API returns details needed to join
    return LiveStreamEntity.fromJson(response.data['data']); // Adjust based on actual API response structure
  }

  // POST /live/leave/:streamId
  Future<void> leaveLiveStream(String streamId) async {
    await _apiClient.dio.post('/live/leave/$streamId');
  }
}