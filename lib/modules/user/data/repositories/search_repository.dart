import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/user_entity.dart';
import '../../../feed/domain/entities/post_entity.dart';

class SearchRepository {
  final ApiClient _apiClient;

  SearchRepository(this._apiClient);

  // GET /post/explore
  Future<List<PostEntity>> getExploreFeed() async {
    const String endpoint = '/post/explore';
    // print('\x1B[34m[SEARCH DEBUG] Fetching Explore Feed: $endpoint\x1B[0m');

    try {
      final response = await _apiClient.dio.get(endpoint);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        List rawList = [];

        if (data is List) {
          rawList = data;
        } else if (data is Map && data['posts'] != null) {
          rawList = data['posts'];
        }

        return rawList.map((e) => PostEntity.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      // print('\x1B[31m[SEARCH DEBUG] Explore Error: $e\x1B[0m');
      return [];
    }
  }

  // GET /search/users?query=...
  Future<List<UserEntity>> searchUsers(String query) async {
    const String endpoint = '/search/users';
    // print('\x1B[34m[SEARCH DEBUG] Searching Users: "$query"\x1B[0m');

    try {
      // FIX: Changed 'q' to 'query' based on 400 Bad Request error
      final response = await _apiClient.dio.get(endpoint, queryParameters: {'query': query});

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        List rawList = [];

        if (data is List) {
          rawList = data;
        } else if (data is Map && data['users'] != null) {
          rawList = data['users'];
        } else if (data is Map) {
          // Fallback if the API returns a different list key
          rawList = data.values.whereType<List>().firstOrNull ?? [];
        }

        return rawList.map((e) => UserEntity.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      // print('\x1B[31m[SEARCH DEBUG] Search Error: $e\x1B[0m');
      return [];
    }
  }
}