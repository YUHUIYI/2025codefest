import 'package:flutter/services.dart';
import 'package:town_pass/config/app_config.dart';

/// Google Maps 配置類別
/// 用於初始化 Google Maps API Key
class GoogleMapsConfig {
  static const MethodChannel _channel = MethodChannel('com.example.townpass/google_maps');

  /// 初始化 Google Maps API Key
  /// 從環境變數讀取並設定到原生平台
  static Future<void> initialize() async {
    try {
      final apiKey = AppConfig.googleMapsApiKey;
      if (apiKey.isNotEmpty && apiKey != 'YOUR_API_KEY_HERE') {
        await _channel.invokeMethod('setApiKey', apiKey);
      } else {
        // 如果沒有設定 API Key，只記錄警告，不拋出錯誤
        print('Warning: Google Maps API Key is not configured in .env file');
        print('Please create .env file with GOOGLE_MAPS_API_KEY=your_key');
      }
    } catch (e) {
      // 如果初始化失敗，只記錄錯誤，不中斷應用程式啟動
      print('Warning: Error initializing Google Maps: $e');
      print('App will continue without Google Maps API Key');
    }
  }
}

