import 'package:get/get.dart';

/// 動滋券導航工具
class SvNavigatorUtil {
  /// 路由名稱
  static const String home = '/sv/home';
  static const String map = '/sv/map';
  static const String textSearch = '/sv/search';
  static const String match = '/sv/match';

  /// 前往首頁
  static void toHome({double? initialBalance}) {
    Get.toNamed(
      home,
      arguments: {'initialBalance': initialBalance},
    );
  }

  /// 前往地圖頁
  static void toMap({double? balance}) {
    Get.toNamed(
      map,
      arguments: {'balance': balance},
    );
  }

  /// 前往文字搜尋頁
  static void toTextSearch({double? balance}) {
    Get.toNamed(
      textSearch,
      arguments: {'balance': balance},
    );
  }

  /// 前往配對頁
  static void toMatch({required double balance}) {
    Get.toNamed(
      match,
      arguments: {'balance': balance},
    );
  }

  /// 返回上一頁
  static void back() {
    Get.back();
  }
}

