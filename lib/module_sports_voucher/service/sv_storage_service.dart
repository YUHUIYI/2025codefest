import 'dart:convert';
import 'package:town_pass/service/shared_preferences_service.dart';

/// 動滋券本地儲存服務
/// 管理使用者的 Like 清單
class SvStorageService {
  static const String _keyLikes = 'sv_likes';
  final SharedPreferencesService _sharedPreferencesService;

  SvStorageService(this._sharedPreferencesService);

  /// 儲存 Like 清單
  Future<void> saveLikes(List<int> merchantIds) async {
    final jsonString = json.encode(merchantIds);
    await _sharedPreferencesService.instance.setString(_keyLikes, jsonString);
  }

  /// 取得 Like 清單
  Future<List<int>> getLikes() async {
    final jsonString = _sharedPreferencesService.instance.getString(_keyLikes);
    if (jsonString == null) {
      return [];
    }
    try {
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList.map((id) => id as int).toList();
    } catch (e) {
      return [];
    }
  }

  /// 加入 Like
  Future<void> addLike(int merchantId) async {
    final likes = await getLikes();
    if (!likes.contains(merchantId)) {
      likes.add(merchantId);
      await saveLikes(likes);
    }
  }

  /// 移除 Like
  Future<void> removeLike(int merchantId) async {
    final likes = await getLikes();
    likes.remove(merchantId);
    await saveLikes(likes);
  }

  /// 檢查是否已 Like
  Future<bool> isLiked(int merchantId) async {
    final likes = await getLikes();
    return likes.contains(merchantId);
  }

  /// 清除所有 Like
  Future<void> clearLikes() async {
    await _sharedPreferencesService.instance.remove(_keyLikes);
  }
}

