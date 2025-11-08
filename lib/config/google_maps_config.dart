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
        print('Warning: Google Maps API Key is not configured');
      }
    } catch (e) {
      print('Error initializing Google Maps: $e');
    }
  }
}

