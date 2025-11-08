import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 應用程式配置類別
/// 用於管理環境變數和 API Keys
class AppConfig {
  /// Google Maps API Key
  static String get googleMapsApiKey {
    return dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  }

  /// 載入環境變數檔案
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // 如果 .env 檔案不存在，使用預設值
      print('Warning: .env file not found. Using default values.');
    }
  }

  /// 檢查必要的環境變數是否已設定
  static bool validate() {
    final apiKey = googleMapsApiKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_API_KEY_HERE') {
      print('Warning: GOOGLE_MAPS_API_KEY is not set in .env file');
      return false;
    }
    return true;
  }
}

