import 'dart:convert';
import 'package:town_pass/service/shared_preferences_service.dart';

/// 動滋券本地儲存服務
/// 管理使用者的 Like 清單和餘額
class SvStorageService {
  static const String _keyLikes = 'sv_likes';
  static const String _keyBalance = 'sv_balance';
  final SharedPreferencesService _sharedPreferencesService;

  SvStorageService(this._sharedPreferencesService);

  /// 儲存 Like 清單
  Future<void> saveLikes(List<String> merchantIds) async {
    final jsonString = json.encode(merchantIds);
    await _sharedPreferencesService.instance.setString(_keyLikes, jsonString);
  }

  /// 取得 Like 清單
  Future<List<String>> getLikes() async {
    final jsonString = _sharedPreferencesService.instance.getString(_keyLikes);
    if (jsonString == null) {
      return [];
    }
    try {
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList.map((id) => id.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  /// 加入 Like
  Future<void> addLike(String merchantId) async {
    final likes = await getLikes();
    if (!likes.contains(merchantId)) {
      likes.add(merchantId);
      await saveLikes(likes);
    }
  }

  /// 移除 Like
  Future<void> removeLike(String merchantId) async {
    final likes = await getLikes();
    likes.remove(merchantId);
    await saveLikes(likes);
  }

  /// 檢查是否已 Like
  Future<bool> isLiked(String merchantId) async {
    final likes = await getLikes();
    return likes.contains(merchantId);
  }

  /// 清除所有 Like
  Future<void> clearLikes() async {
    await _sharedPreferencesService.instance.remove(_keyLikes);
  }

  /// 儲存餘額
  Future<void> saveBalance(double balance) async {
    await _sharedPreferencesService.instance.setDouble(_keyBalance, balance);
  }

  /// 取得餘額
  Future<double?> getBalance() async {
    return _sharedPreferencesService.instance.getDouble(_keyBalance);
  }

  /// 清除餘額
  Future<void> clearBalance() async {
    await _sharedPreferencesService.instance.remove(_keyBalance);
  }
}

