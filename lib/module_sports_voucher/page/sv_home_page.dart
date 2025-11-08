import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:town_pass/gen/assets.gen.dart';
import 'package:town_pass/module_sports_voucher/service/sv_storage_service.dart';
import 'package:town_pass/module_sports_voucher/util/sv_dialog_util.dart';
import 'package:town_pass/module_sports_voucher/util/sv_navigator_util.dart';
import 'package:town_pass/service/shared_preferences_service.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_text.dart';
import 'package:town_pass/util/tp_text_styles.dart';

/// 動滋券首頁
class SvHomePage extends StatefulWidget {
  final double? initialBalance;

  const SvHomePage({super.key, this.initialBalance});

  @override
  State<SvHomePage> createState() {
    print('[DEBUG] SvHomePage.createState called with initialBalance: $initialBalance');
    return _SvHomePageState();
  }
}

class _SvHomePageState extends State<SvHomePage> {
  final TextEditingController _balanceController = TextEditingController();
  final FocusNode _balanceFocusNode = FocusNode();
  late final SvStorageService _storageService;
  double? _savedBalance;

  @override
  void initState() {
    super.initState();
    print('[DEBUG] SvHomePage.initState called');
    print('[DEBUG] InitialBalance: ${widget.initialBalance}');
    _storageService = SvStorageService(Get.find<SharedPreferencesService>());
    _loadSavedBalance();
    if (widget.initialBalance != null) {
      _balanceController.text = widget.initialBalance!.toStringAsFixed(0);
    }
  }

  Future<void> _loadSavedBalance() async {
    final balance = await _storageService.getBalance();
    if (mounted) {
      setState(() {
        _savedBalance = balance;
        if (balance != null && _balanceController.text.isEmpty) {
          _balanceController.text = balance.toStringAsFixed(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _balanceFocusNode.dispose();
    super.dispose();
  }

  Future<void> _launchOfficialWebsite() async {
    final uri = Uri.parse('https://500.gov.tw/FOAS/actions/Consumer114User.action?voucherList');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        SvDialogUtil.showErrorDialog(context, '無法開啟官方網站');
      }
    }
  }

  Future<void> _saveBalance() async {
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

    await _storageService.saveBalance(balance);
    setState(() {
      _savedBalance = balance;
    });

    if (mounted) {
      Get.snackbar(
        '成功',
        '餘額已儲存',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: TPColors.primary500,
        colorText: TPColors.white,
        duration: const Duration(seconds: 2),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    print('[DEBUG] SvHomePage.build called');
    return Scaffold(
      backgroundColor: TPColors.primary50,
      appBar: TPAppBar(
        title: '動滋券查詢',
        backgroundColor: TPColors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner 圖片
            _buildBanner(),
            // 大卡片：輸入金額區域
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildBalanceInputCard(),
            ),
            // 查詢選項區域
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
                    child: Text(
                      '查詢方式',
                      style: TPTextStyles.h3SemiBold.copyWith(
                        color: TPColors.grayscale900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildServiceCard(
                          icon: Assets.svg.iconLocationSearch24.svg(),
                          title: '地圖查詢',
                          description: '查看店家位置',
                          onTap: () {
                            final balance = _savedBalance ?? double.tryParse(_balanceController.text.trim());
                            if (balance != null && balance > 0) {
                              SvNavigatorUtil.toMap(balance: balance);
                            } else {
                              SvNavigatorUtil.toMap(balance: null);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildServiceCard(
                          icon: Assets.svg.iconCaseSearch.svg(),
                          title: '文字搜尋',
                          description: '搜尋店家名稱',
                          onTap: () {
                            final balance = _savedBalance ?? double.tryParse(_balanceController.text.trim());
                            SvNavigatorUtil.toTextSearch(balance: balance);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildServiceCard(
                          icon: Icon(
                            Icons.favorite,
                            size: 40,
                            color: _savedBalance != null && _savedBalance! > 0
                                ? TPColors.primary500
                                : TPColors.grayscale400,
                          ),
                          title: '餘額配對',
                          description: '滑動配對店家',
                          onTap: _savedBalance != null && _savedBalance! > 0
                              ? () {
                                  SvNavigatorUtil.toMatch(balance: _savedBalance!);
                                }
                              : null,
                          isEnabled: _savedBalance != null && _savedBalance! > 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 官方網站連結
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildOfficialWebsiteCard(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      height: 180,
      margin: const EdgeInsets.only(bottom: 16),
      child: Image.asset(
        'assets/image/sv_banner.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // 如果圖片不存在，顯示佔位符
          return Container(
            color: TPColors.primary100,
            child: Center(
              child: Text(
                'Banner 圖片',
                style: TPTextStyles.bodyRegular.copyWith(
                  color: TPColors.grayscale600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceInputCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TPColors.primary400,
            TPColors.primary500,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: TPColors.primary500.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: TPColors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Assets.svg.iconCouponTicket.svg(
                    colorFilter: const ColorFilter.mode(
                      TPColors.white,
                      BlendMode.srcIn,
                    ),
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '輸入剩餘金額',
                      style: TPTextStyles.h2SemiBold.copyWith(
                        color: TPColors.white,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '儲存餘額以便查詢',
                      style: TPTextStyles.bodyRegular.copyWith(
                        color: TPColors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: TPColors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _balanceController,
              focusNode: _balanceFocusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TPTextStyles.h3SemiBold.copyWith(
                color: TPColors.grayscale950,
                fontSize: 18,
              ),
              decoration: InputDecoration(
                hintText: '請輸入金額',
                prefixText: 'NT\$ ',
                prefixStyle: TPTextStyles.h3SemiBold.copyWith(
                  color: TPColors.grayscale700,
                  fontSize: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: TPColors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveBalance,
              style: ElevatedButton.styleFrom(
                backgroundColor: TPColors.white,
                foregroundColor: TPColors.primary500,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                '儲存餘額',
                style: TPTextStyles.h3SemiBold.copyWith(
                  color: TPColors.primary500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required Widget icon,
    required String title,
    required String description,
    required VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          decoration: BoxDecoration(
            color: TPColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: TPColors.grayscale100,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: TPColors.grayscale100,
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: icon,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TPTextStyles.bodySemiBold.copyWith(
                  color: TPColors.grayscale900,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TPTextStyles.caption.copyWith(
                  color: TPColors.grayscale700,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficialWebsiteCard() {
    return GestureDetector(
      onTap: _launchOfficialWebsite,
      child: Container(
        decoration: BoxDecoration(
          color: TPColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: TPColors.grayscale100,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: TPColors.grayscale100,
              blurRadius: 8,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: TPColors.primary100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: TPColors.primary200,
                  width: 1,
                ),
              ),
              child: Center(
                child: Assets.svg.iconCouponTicket.svg(
                  colorFilter: const ColorFilter.mode(
                    TPColors.primary500,
                    BlendMode.srcIn,
                  ),
                  width: 24,
                  height: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '動滋券官方網站',
                    style: TPTextStyles.h3SemiBold.copyWith(
                      color: TPColors.grayscale900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '查詢餘額及了解相關資訊',
                    style: TPTextStyles.caption.copyWith(
                      color: TPColors.grayscale700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: TPColors.grayscale400,
            ),
          ],
        ),
      ),
    );
  }
}
