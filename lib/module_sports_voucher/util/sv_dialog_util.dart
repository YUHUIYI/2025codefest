import 'package:flutter/material.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_text_styles.dart';

/// 動滋券對話框工具
class SvDialogUtil {
  /// 顯示錯誤對話框
  static void showErrorDialog(
    BuildContext context,
    String message, {
    String title = '錯誤',
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: TPTextStyles.h3SemiBold.copyWith(color: TPColors.grayscale950),
        ),
        content: Text(
          message,
          style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '確定',
              style: TPTextStyles.bodySemiBold.copyWith(color: TPColors.primary500),
            ),
          ),
        ],
      ),
    );
  }

  /// 顯示確認對話框
  static Future<bool> showConfirmDialog(
    BuildContext context,
    String message, {
    String title = '確認',
    String confirmText = '確定',
    String cancelText = '取消',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: TPTextStyles.h3SemiBold.copyWith(color: TPColors.grayscale950),
        ),
        content: Text(
          message,
          style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              cancelText,
              style: TPTextStyles.bodySemiBold.copyWith(color: TPColors.grayscale600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              confirmText,
              style: TPTextStyles.bodySemiBold.copyWith(color: TPColors.primary500),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 顯示載入中對話框
  static void showLoadingDialog(BuildContext context, {String message = '載入中...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                message,
                style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 關閉對話框
  static void dismissDialog(BuildContext context) {
    Navigator.of(context).pop();
  }
}

