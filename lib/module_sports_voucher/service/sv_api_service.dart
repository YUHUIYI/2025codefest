import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:town_pass/module_sports_voucher/bean/sv_merchant.dart';
import 'package:town_pass/config/app_config.dart';

/// 動滋券 API 服務
class SvApiService {
  final http.Client _client;

  SvApiService({http.Client? client}) : _client = client ?? http.Client();

  /// 建構 API URI
  Uri _buildUri(String path, {Map<String, String>? queryParameters}) {
    final baseUrl = AppConfig.apiBaseUrl;
    final uri = Uri.parse(baseUrl);
    return uri.replace(
      path: '${uri.path}$path',
      queryParameters: queryParameters,
    );
  }

  /// 取得所有合作店家
  Future<List<SvMerchant>> fetchMerchants() async {
    try {
      final response = await _client.get(
        _buildUri('/stores'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('取得店家資料失敗：HTTP ${response.statusCode}');
      }

      final decoded = json.decode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>?;

      if (data == null || data.isEmpty) {
        return [];
      }

      return data.map((item) {
        final store = item as Map<String, dynamic>;
        final storeId = store['store_id'];
        return SvMerchant(
          id: storeId != null ? storeId.toString() : store['id'] as String? ?? '',
          name: store['store_name'] as String? ?? store['name'] as String? ?? '',
          address: store['address'] as String? ?? '',
          lat: _extractLatitude(store),
          lng: _extractLongitude(store),
          minSpend: _extractMinPrice(store),
          phone: store['phone'] as String?,
          description: store['description'] as String?,
          imageUrl: store['image_url'] as String?,
        );
      }).toList();
    } catch (e) {
      print('取得店家資料失敗：$e');
      // 如果 API 失敗，返回空列表
      return [];
    }
  }

  /// 根據餘額取得可用店家
  Future<List<SvMerchant>> fetchAffordableMerchants(double balance) async {
    final merchants = await fetchMerchants();
    return merchants.where((merchant) => merchant.isAffordable(balance)).toList();
  }

  /// 根據 ID 取得店家
  Future<SvMerchant?> fetchMerchantById(String id) async {
    try {
      final response = await _client.get(
        _buildUri('/stores/$id'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = json.decode(response.body) as Map<String, dynamic>;
      final store = decoded['data'] as Map<String, dynamic>?;

      if (store == null) {
        return null;
      }

      final storeId = store['store_id'];
      return SvMerchant(
        id: storeId != null ? storeId.toString() : store['id'] as String? ?? id,
        name: store['store_name'] as String? ?? store['name'] as String? ?? '',
        address: store['address'] as String? ?? '',
        lat: _extractLatitude(store),
        lng: _extractLongitude(store),
        minSpend: _extractMinPrice(store),
        phone: store['phone'] as String?,
        description: store['description'] as String?,
        imageUrl: store['image_url'] as String?,
      );
    } catch (e) {
      print('取得店家資料失敗：$e');
      return null;
    }
  }

  /// 從 store 資料中提取緯度
  double _extractLatitude(Map<String, dynamic> store) {
    try {
      final location = store['location'];
      if (location is Map) {
        // Firestore GeoPoint 格式：{"latitude": xxx, "longitude": xxx}
        final lat = location['latitude'] ?? location['_latitude'];
        if (lat != null) {
          return (lat as num).toDouble();
        }
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// 從 store 資料中提取經度
  double _extractLongitude(Map<String, dynamic> store) {
    try {
      final location = store['location'];
      if (location is Map) {
        // Firestore GeoPoint 格式：{"latitude": xxx, "longitude": xxx}
        final lng = location['longitude'] ?? location['_longitude'];
        if (lng != null) {
          return (lng as num).toDouble();
        }
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// 從 store 資料中提取最低價格
  double _extractMinPrice(Map<String, dynamic> store) {
    try {
      final priceRange = store['price_range'];
      if (priceRange is Map) {
        final min = priceRange['min'];
        if (min != null) {
          return (min as num).toDouble();
        }
      }
      // 如果沒有 price_range，使用預設值
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// 從 Firestore 取得所有有產品的店家（用於配對頁面）
  /// 最低消費 = 該店家最便宜的 product 價格
  Future<List<SvMerchant>> fetchMerchantsWithProducts() async {
    try {
      final db = FirebaseFirestore.instance;

      // 步驟 1: 取得所有 products
      final productsSnapshot = await db.collection('products').get();
      
      if (productsSnapshot.docs.isEmpty) {
        print('[SvApiService] 沒有找到任何 products');
        return [];
      }

      // 步驟 2: 計算每個 store_id 的最低價格
      // Map<storeId, minPrice>
      final Map<String, double> storeMinPrices = {};
      
      for (final doc in productsSnapshot.docs) {
        final data = doc.data();
        final storeId = data['store_id'];
        final price = data['price'];
        
        if (storeId != null && price != null) {
          // store_id 可能是數字或字串，統一轉為字串
          final storeIdStr = storeId.toString();
          final priceNum = (price is num) ? price.toDouble() : double.tryParse(price.toString()) ?? 0.0;
          
          if (priceNum > 0) {
            // 如果該 store 還沒有記錄，或找到更便宜的價格，則更新
            if (!storeMinPrices.containsKey(storeIdStr) || 
                storeMinPrices[storeIdStr]! > priceNum) {
              storeMinPrices[storeIdStr] = priceNum;
            }
          }
        }
      }

      if (storeMinPrices.isEmpty) {
        print('[SvApiService] 沒有找到有效的 store_id 和 price');
        return [];
      }

      print('[SvApiService] 找到 ${storeMinPrices.length} 個有產品的店家');

      // 步驟 3: 取得所有有產品的 stores（is_active == true）
      final storesSnapshot = await db
          .collection('stores')
          .where('is_active', isEqualTo: true)
          .get();

      if (storesSnapshot.docs.isEmpty) {
        print('[SvApiService] 沒有找到任何 active stores');
        return [];
      }

      // 步驟 4: 合併資料，只保留有產品的 stores
      final List<SvMerchant> merchants = [];

      for (final doc in storesSnapshot.docs) {
        final storeData = doc.data();
        final sourceStoreId = storeData['source_store_id']?.toString();
        
        // 檢查該 store 是否有對應的 product
        if (sourceStoreId != null && storeMinPrices.containsKey(sourceStoreId)) {
          final minPrice = storeMinPrices[sourceStoreId]!;
          
          // 建立 SvMerchant
          final location = storeData['location'];
          double lat = 0.0;
          double lng = 0.0;
          
          if (location is GeoPoint) {
            lat = location.latitude;
            lng = location.longitude;
          } else if (location is Map) {
            lat = (location['latitude'] ?? location['lat'] ?? 0.0) as double;
            lng = (location['longitude'] ?? location['lng'] ?? 0.0) as double;
          } else if (location is List && location.length >= 2) {
            lat = (location[0] as num?)?.toDouble() ?? 0.0;
            lng = (location[1] as num?)?.toDouble() ?? 0.0;
          }

          final merchant = SvMerchant(
            id: doc.id,
            name: storeData['store_name']?.toString() ?? '',
            address: storeData['address']?.toString() ?? '',
            lat: lat,
            lng: lng,
            minSpend: minPrice, // 使用從 products 計算出的最低價格
            phone: storeData['phone']?.toString(),
            description: storeData['description']?.toString(),
            imageUrl: storeData['image_url']?.toString(),
            category: storeData['custom_category']?.toString() ?? 
                     storeData['official_category_auto']?.toString(),
            businessHours: storeData['businessHours']?.toString(),
            website: storeData['website']?.toString(),
            isActive: storeData['is_active'] as bool? ?? true,
            updatedAt: storeData['updated_at'] is Timestamp
                ? (storeData['updated_at'] as Timestamp).toDate()
                : null,
          );

          merchants.add(merchant);
        }
      }

      print('[SvApiService] 成功取得 ${merchants.length} 個有產品的店家');
      return merchants;
    } catch (e, stackTrace) {
      print('[SvApiService] 取得店家資料失敗：$e');
      print('[SvApiService] Stack trace: $stackTrace');
      return [];
    }
  }

  /// 根據餘額取得可用店家（使用 products 計算最低消費）
  Future<List<SvMerchant>> fetchAffordableMerchantsWithProducts(double balance) async {
    final merchants = await fetchMerchantsWithProducts();
    return merchants.where((merchant) => merchant.isAffordable(balance)).toList();
  }
}
