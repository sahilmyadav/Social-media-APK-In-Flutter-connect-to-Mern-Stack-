import '../../../../core/network/api_client.dart';
import '../../../../modules/user/domain/entities/user_entity.dart';

class SettingsRepository {
  final ApiClient _apiClient;

  SettingsRepository(this._apiClient);

  Future<void> changePassword(String current, String newPass) async {
    await _apiClient.dio.post('/users/change-password', data: {
      "currentPassword": current,
      "newPassword": newPass
    });
  }

  Future<void> updatePrivacy({bool? isPrivate}) async {
    await _apiClient.dio.put('/users/privacy-settings', data: {
      "isPrivate": isPrivate
    });
  }

  Future<List<UserEntity>> getBlockedUsers() async {
    try {
      final response = await _apiClient.dio.get('/users/blocked-list');
      final List data = response.data['data'];
      return data.map((e) => UserEntity.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> unblockUser(String userId) async {
    await _apiClient.dio.post('/users/unblock/$userId');
  }

  Future<void> logout() async {
    await _apiClient.dio.post('/users/logout');
  }
}