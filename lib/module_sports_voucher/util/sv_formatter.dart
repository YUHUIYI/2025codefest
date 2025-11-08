import 'package:intl/intl.dart';

/// 動茲券格式化工具
class SvFormatter {
  /// 格式化金額（新台幣）
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      symbol: 'NT\$',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  /// 格式化距離（公里）
  static String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).toStringAsFixed(0)} 公尺';
    }
    return '${distanceInKm.toStringAsFixed(1)} 公里';
  }

  /// 格式化日期時間
  static String formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('yyyy/MM/dd HH:mm');
    return formatter.format(dateTime);
  }

  /// 格式化日期
  static String formatDate(DateTime date) {
    final formatter = DateFormat('yyyy/MM/dd');
    return formatter.format(date);
  }
}

