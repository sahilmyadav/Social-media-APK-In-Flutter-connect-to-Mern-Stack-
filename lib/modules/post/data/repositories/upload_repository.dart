import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';

class UploadRepository {
  final ApiClient _apiClient;

  UploadRepository(this._apiClient);

  //// 1. Upload Post (Supports up to 10 images/videos)
  Future<void> uploadPost({
    required List<File> files,
    required String caption,
    List<String>? tags,
    String? location,
    String visibility = 'public',
  }) async {
    try {
      debugPrint("🚀 Starting Post Upload: ${files.length} files");

      List<MultipartFile> multipartFiles = [];
      for (var file in files) {
        String fileName = file.path.split('/').last;
        multipartFiles.add(await MultipartFile.fromFile(file.path, filename: fileName));
      }

      String? tagsString = tags?.join(',');

      FormData formData = FormData.fromMap({
        "files": multipartFiles,
        "caption": caption,
        if (tagsString != null && tagsString.isNotEmpty) "tags": tagsString,
        if (location != null && location.isNotEmpty) "location": location,
        "visibility": visibility,
      });

      final response = await _apiClient.dio.post('/post/upload', data: formData);
      debugPrint("✅ Post Upload Success: ${response.data}");
    } catch (e) {
      debugPrint("❌ Post Upload Error: $e");
      rethrow;
    }
  }

  //// 2. Upload Reel (Single video file)
  Future<void> uploadReel({
    required File videoFile,
    String? caption,
    String? audioId,
    List<String>? tags,
  }) async {
    try {
      debugPrint("🚀 Starting Reel Upload: ${videoFile.path}");

      String fileName = videoFile.path.split('/').last;
      String? tagsString = tags?.join(',');

      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(videoFile.path, filename: fileName),
        if (caption != null) "caption": caption,
        if (audioId != null) "audio": audioId,
        if (tagsString != null) "tags": tagsString,
      });

      final response = await _apiClient.dio.post('/reel/upload', data: formData);
      debugPrint("✅ Reel Upload Success: ${response.data}");
    } catch (e) {
      debugPrint("❌ Reel Upload Error: $e");
      rethrow;
    }
  }

  //// 3. Upload Story (24hr temporary post)
  Future<void> uploadStory({
    required File file,
    String? caption,
    int? duration,
  }) async {
    try {
      debugPrint("🚀 Starting Story Upload: ${file.path}");

      String fileName = file.path.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(file.path, filename: fileName),
        if (caption != null) "caption": caption,
        if (duration != null) "duration": duration,
      });

      final response = await _apiClient.dio.post('/story/upload', data: formData);
      debugPrint("✅ Story Upload Success: ${response.data}");
    } catch (e) {
      debugPrint("❌ Story Upload Error: $e");
      rethrow;
    }
  }

  //// 4. Search Users for Tagging
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];

      final response = await _apiClient.dio.get(
        '/search/users',
        queryParameters: {
          'query': query,
          'limit': 10,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> usersJson = response.data['data']['users'];
        return usersJson.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint("❌ Search Users Error: $e");
      return [];
    }
  }

  //// 5. Search Songs (Saavn API)
  Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    try {
      // Using a fresh Dio instance or full URL since this is an external API
      final dio = Dio();
      final response = await dio.get(
        'https://saavn.sumit.co/api/search/songs',
        queryParameters: {
          'query': query.isEmpty ? 'trending hits' : query,
          'limit': 25,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> results = response.data['data']['results'];
        return results.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint("❌ Search Songs Error: $e");
      return [];
    }
  }
}