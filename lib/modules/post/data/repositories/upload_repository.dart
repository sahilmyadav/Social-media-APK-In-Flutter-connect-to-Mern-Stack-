import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';

class UploadRepository {
  final ApiClient _apiClient;

  UploadRepository(this._apiClient);

  Future<void> uploadPost({
    required List<File> files,
    required String caption,
    String? location,
  }) async {
    List<MultipartFile> multipartFiles = [];
    for (var file in files) {
      String fileName = file.path.split('/').last;
      multipartFiles.add(await MultipartFile.fromFile(file.path, filename: fileName));
    }

    FormData formData = FormData.fromMap({
      "files": multipartFiles,
      "caption": caption,
      if (location != null) "location": location,
    });

    await _apiClient.dio.post('/post/upload', data: formData);
  }

  Future<void> uploadReel({required File videoFile, String? caption}) async {
    String fileName = videoFile.path.split('/').last;
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(videoFile.path, filename: fileName),
      "caption": caption,
    });

    await _apiClient.dio.post('/reel/upload', data: formData);
  }
}