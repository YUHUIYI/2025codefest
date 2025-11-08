import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:town_pass/module_sports_voucher/bean/sv_merchant.dart';
import 'package:town_pass/module_sports_voucher/service/sv_api_service.dart';
import 'package:town_pass/module_sports_voucher/service/sv_location_service.dart';
import 'package:town_pass/module_sports_voucher/service/sv_storage_service.dart';

/// 動滋券推薦演算法服務
class SvRecommendationService {
  final SvApiService _apiService;
  final SvLocationService _locationService;
  final SvStorageService _storageService;
  final Random _random = Random();

  SvRecommendationService({
    required SvApiService apiService,
    required SvLocationService locationService,
    required SvStorageService storageService,
  })  : _apiService = apiService,
        _locationService = locationService,
        _storageService = storageService;

  /// 取得推薦的店家列表
  /// 
  /// 演算法邏輯：
  /// 1. 依權重隨機選類別（權重高的機率高，但不是固定先出現）
  /// 2. 確保每種類別至少出現1次（從未出現的類別中依權重選擇）
  /// 3. 從選中的類別選距離最近的店家
  /// 4. 所有類別都出現過後，繼續依權重隨機推薦
  Future<List<SvMerchant>> getRecommendedMerchants({
    required Position userPosition,
    double? balance,
  }) async {
    // 取得所有店家
    final List<SvMerchant> allMerchants;
    if (balance != null && balance > 0) {
      allMerchants = await _apiService.fetchAffordableMerchantsWithProducts(balance);
    } else {
      allMerchants = await _apiService.fetchMerchantsWithProducts();
    }

    if (allMerchants.isEmpty) {
      return [];
    }

    // 計算所有店家的距離（只計算一次）
    final List<MapEntry<SvMerchant, double>> merchantsWithDistance = [];
    for (final merchant in allMerchants) {
      final distance = _locationService.calculateDistance(
        userPosition.latitude,
        userPosition.longitude,
        merchant.lat,
        merchant.lng,
      );
      merchantsWithDistance.add(MapEntry(merchant, distance));
    }

    // 依類別分組，並依距離排序
    final Map<String, List<MapEntry<SvMerchant, double>>> categoryGroups = {};
    for (final entry in merchantsWithDistance) {
      final category = entry.key.category ?? '其他';
      if (!categoryGroups.containsKey(category)) {
        categoryGroups[category] = [];
      }
      categoryGroups[category]!.add(entry);
    }

    // 每個類別內的店家依距離排序
    for (final category in categoryGroups.keys) {
      categoryGroups[category]!.sort((a, b) => a.value.compareTo(b.value));
    }

    // 取得所有類別列表
    final categories = categoryGroups.keys.toList();
    
    // 初始化類別權重
    await _storageService.initializeCategoryWeights(categories);

    // 取得類別權重
    final categoryWeights = await _storageService.getCategoryWeights();

    // 確保所有類別都有權重（預設為1）
    for (final category in categories) {
      if (!categoryWeights.containsKey(category)) {
        categoryWeights[category] = 1;
      }
    }

    // 實作推薦邏輯
    final List<SvMerchant> recommendedMerchants = [];
    final Set<String> usedMerchantIds = {};
    final Set<String> categoriesShown = {}; // 追蹤已出現的類別

    // 準備剩餘店家列表（所有店家）
    final Map<String, List<MapEntry<SvMerchant, double>>> remainingByCategory = {};
    for (final category in categoryGroups.keys) {
      final remaining = categoryGroups[category]!
          .where((entry) => !usedMerchantIds.contains(entry.key.id))
          .toList();
      if (remaining.isNotEmpty) {
        remainingByCategory[category] = remaining;
      }
    }

    // 統一的推薦邏輯：依權重隨機選類別，但確保每種類別至少出現1次
    while (remainingByCategory.isNotEmpty) {
      String? selectedCategory;
      
      // 如果還有未出現的類別，優先從中選擇（但仍依權重）
      final unshownCategories = remainingByCategory.keys
          .where((cat) => !categoriesShown.contains(cat))
          .toList();
      
      if (unshownCategories.isNotEmpty) {
        // 從未出現的類別中，依權重隨機選
        selectedCategory = selectCategoryByWeight(categoryWeights, unshownCategories);
      } else {
        // 所有類別都出現過了，就依權重隨機選任何類別
        selectedCategory = selectCategoryByWeight(categoryWeights, remainingByCategory.keys.toList());
      }
      
      if (selectedCategory == null || !remainingByCategory.containsKey(selectedCategory)) {
        break;
      }

      // 從該類別選距離最近的未使用店家
      final merchants = remainingByCategory[selectedCategory]!;
      if (merchants.isNotEmpty) {
        final entry = merchants.first;
        recommendedMerchants.add(entry.key);
        usedMerchantIds.add(entry.key.id);
        categoriesShown.add(selectedCategory);
        
        // 從列表中移除已使用的店家
        merchants.removeAt(0);
        if (merchants.isEmpty) {
          remainingByCategory.remove(selectedCategory);
        }
      } else {
        remainingByCategory.remove(selectedCategory);
      }
    }

    return recommendedMerchants;
  }

  /// 依權重隨機選類別
  /// 
  /// 例如：類別A權重2，類別B權重1，總和3
  /// 則A的機率為2/3，B的機率為1/3
  String? selectCategoryByWeight(
    Map<String, int> weights,
    List<String> availableCategories,
  ) {
    if (availableCategories.isEmpty) {
      return null;
    }

    // 計算總權重（只計算可用類別）
    int totalWeight = 0;
    for (final category in availableCategories) {
      totalWeight += weights[category] ?? 1;
    }

    if (totalWeight == 0) {
      return availableCategories[_random.nextInt(availableCategories.length)];
    }

    // 隨機選一個數字（0 到 totalWeight-1）
    int randomValue = _random.nextInt(totalWeight);

    // 依權重累加，找到對應的類別
    int cumulative = 0;
    for (final category in availableCategories) {
      final weight = weights[category] ?? 1;
      cumulative += weight;
      if (randomValue < cumulative) {
        return category;
      }
    }

    // 如果沒找到（理論上不應該發生），返回第一個
    return availableCategories.first;
  }
}

