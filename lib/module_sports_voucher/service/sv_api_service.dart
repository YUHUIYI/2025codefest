import 'dart:convert';
import 'package:http/http.dart' as http;
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
    final allMerchants = await fetchMerchants();
    return allMerchants.where((merchant) => merchant.isAffordable(balance)).toList();
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
}
