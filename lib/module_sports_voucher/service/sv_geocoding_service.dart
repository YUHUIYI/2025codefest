import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:town_pass/config/app_config.dart';

/// 動滋券地理編碼服務
/// 使用 Google Geocoding API 將地址轉換為經緯度座標
class SvGeocodingService {
  final http.Client _client;

  SvGeocodingService({http.Client? client}) : _client = client ?? http.Client();

  /// 從地址取得座標
  /// 
  /// 使用 Google Geocoding API 將地址字串轉換為 LatLng 座標
  /// 如果查詢失敗或找不到結果，回傳 null
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    if (address.isEmpty) {
      return null;
    }

    try {
      final apiKey = AppConfig.googleMapsApiKey;
      if (apiKey.isEmpty || apiKey == 'YOUR_API_KEY_HERE') {
        print('Warning: Google Maps API Key not configured');
        return null;
      }

      // 建構 Geocoding API 請求
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'address': address,
          'key': apiKey,
          'language': 'zh-TW', // 使用繁體中文
          'region': 'tw', // 偏好台灣地區結果
        },
      );

      final response = await _client.get(uri);

      if (response.statusCode != 200) {
        print('Geocoding API error: HTTP ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status != 'OK') {
        print('Geocoding API status: $status');
        return null;
      }

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        print('Geocoding: No results found for address: $address');
        return null;
      }

      // 取得第一個結果的座標
      final firstResult = results[0] as Map<String, dynamic>;
      final geometry = firstResult['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;

      if (location == null) {
        print('Geocoding: No location data in result');
        return null;
      }

      final lat = location['lat'] as num?;
      final lng = location['lng'] as num?;

      if (lat == null || lng == null) {
        print('Geocoding: Invalid coordinates in result');
        return null;
      }

      return LatLng(lat.toDouble(), lng.toDouble());
    } catch (e) {
      print('Geocoding error for address "$address": $e');
      return null;
    }
  }

  /// 批次取得多個地址的座標
  /// 
  /// 為了避免超過 API 配額限制，建議在後端預先處理
  /// 此方法會依序查詢每個地址，並在每次請求間加入延遲
  Future<Map<String, LatLng>> batchGetCoordinates(
    List<String> addresses, {
    Duration delayBetweenRequests = const Duration(milliseconds: 200),
  }) async {
    final results = <String, LatLng>{};

    for (final address in addresses) {
      final coordinates = await getCoordinatesFromAddress(address);
      if (coordinates != null) {
        results[address] = coordinates;
      }

      // 加入延遲避免超過 API rate limit
      if (addresses.indexOf(address) < addresses.length - 1) {
        await Future.delayed(delayBetweenRequests);
      }
    }

    return results;
  }
}

