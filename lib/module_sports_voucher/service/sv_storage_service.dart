import 'dart:convert';
import 'package:town_pass/service/shared_preferences_service.dart';

/// 動滋券本地儲存服務
/// 管理使用者的 Like 清單和餘額
class SvStorageService {
  static const String _keyLikes = 'sv_likes';
  static const String _keyBalance = 'sv_balance';
  static const String _keyCategoryWeights = 'sv_category_weights';
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

  /// 取得類別權重
  Future<Map<String, int>> getCategoryWeights() async {
    final jsonString = _sharedPreferencesService.instance.getString(_keyCategoryWeights);
    if (jsonString == null) {
      return {};
    }
    try {
      final Map<String, dynamic> jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      return jsonMap.map((key, value) => MapEntry(key, (value as num).toInt()));
    } catch (e) {
      return {};
    }
  }

  /// 儲存類別權重
  Future<void> saveCategoryWeights(Map<String, int> weights) async {
    final jsonString = json.encode(weights);
    await _sharedPreferencesService.instance.setString(_keyCategoryWeights, jsonString);
  }

  /// 增加類別權重（Like時調用）
  Future<void> incrementCategoryWeight(String category) async {
    if (category.isEmpty) return;
    
    final weights = await getCategoryWeights();
    final currentWeight = weights[category] ?? 1;
    weights[category] = currentWeight + 1;
    await saveCategoryWeights(weights);
  }

  /// 初始化所有類別權重為1
  Future<void> initializeCategoryWeights(List<String> categories) async {
    final weights = await getCategoryWeights();
    bool needsUpdate = false;
    
    for (final category in categories) {
      if (category.isNotEmpty && !weights.containsKey(category)) {
        weights[category] = 1;
        needsUpdate = true;
      }
    }
    
    if (needsUpdate) {
      await saveCategoryWeights(weights);
    }
  }

  /// 清除類別權重
  Future<void> clearCategoryWeights() async {
    await _sharedPreferencesService.instance.remove(_keyCategoryWeights);
  }

  /// 清除所有動滋券相關資料（用於開發/測試）
  Future<void> clearAllData() async {
    await clearLikes();
    await clearBalance();
    await clearCategoryWeights();
  }
}

