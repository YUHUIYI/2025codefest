import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:town_pass/module_sports_voucher/util/sv_dialog_util.dart';
import 'package:town_pass/module_sports_voucher/util/sv_navigator_util.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_button.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_text.dart';
import 'package:town_pass/util/tp_text_styles.dart';

/// 動茲券首頁
class SvHomePage extends StatefulWidget {
  final double? initialBalance;

  const SvHomePage({super.key, this.initialBalance});

  @override
  State<SvHomePage> createState() => _SvHomePageState();
}

class _SvHomePageState extends State<SvHomePage> {
  final TextEditingController _balanceController = TextEditingController();
  final FocusNode _balanceFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.initialBalance != null) {
      _balanceController.text = widget.initialBalance!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _balanceFocusNode.dispose();
    super.dispose();
  }

  Future<void> _launchOfficialWebsite() async {
    final uri = Uri.parse('https://sportsvoucher.gov.tw');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        SvDialogUtil.showErrorDialog(context, '無法開啟官方網站');
      }
    }
  }

  void _startSearch() {
    final balanceText = _balanceController.text.trim();
    if (balanceText.isEmpty) {
      SvDialogUtil.showErrorDialog(context, '請輸入剩餘金額');
      return;
    }

    final balance = double.tryParse(balanceText);
    if (balance == null || balance < 0) {
      SvDialogUtil.showErrorDialog(context, '請輸入有效的金額');
      return;
    }

    _showSearchOptions(balance);
  }

  void _showSearchOptions(double balance) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '選擇查詢方式',
              style: TPTextStyles.h2SemiBold.copyWith(color: TPColors.grayscale950),
            ),
            const SizedBox(height: 24),
            TPButton.primary(
              text: '地圖查詢',
              onPressed: () {
                Navigator.pop(context);
                SvNavigatorUtil.toMap(balance: balance);
              },
            ),
            const SizedBox(height: 12),
            TPButton.primary(
              text: '配對推薦',
              onPressed: () {
                Navigator.pop(context);
                SvNavigatorUtil.toMatch(balance: balance);
              },
            ),
            const SizedBox(height: 12),
            TPButton.secondary(
              text: '文字搜尋',
              onPressed: () {
                Navigator.pop(context);
                SvNavigatorUtil.toTextSearch(balance: balance);
              },
            ),
            const SizedBox(height: 12),
            TPButton.secondary(
              text: '取消',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TPAppBar(
        title: '動茲券查詢',
        backgroundColor: TPColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Text(
              '輸入剩餘金額',
              style: TPTextStyles.h2SemiBold.copyWith(color: TPColors.grayscale950),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _balanceController,
              focusNode: _balanceFocusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '金額（新台幣）',
                hintText: '請輸入剩餘金額',
                prefixText: 'NT\$ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: TPColors.grayscale50,
              ),
              style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale950),
            ),
            const SizedBox(height: 32),
            TPButton.primary(
              text: '開始查詢',
              onPressed: _startSearch,
            ),
            const SizedBox(height: 24),
            TPButton.secondary(
              text: '前往動茲券官方網站',
              onPressed: _launchOfficialWebsite,
            ),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TPColors.primary50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '使用說明',
                    style: TPTextStyles.h3SemiBold.copyWith(color: TPColors.grayscale950),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 輸入您的動茲券剩餘金額\n• 選擇查詢方式：地圖、配對或文字搜尋\n• 瀏覽可用動茲券消費的合作店家\n• 將喜歡的店家加入收藏',
                    style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

