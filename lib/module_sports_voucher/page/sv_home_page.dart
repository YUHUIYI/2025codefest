import 'package:carousel_slider/carousel_slider.dart';
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

  final List<String> _bannerImages = const [
    'assets/image/sv_banner.png',
    'assets/image/sv_banner_2.png',
  ];

  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    print('[DEBUG] SvHomePage.initState called');
    print('[DEBUG] InitialBalance: ${widget.initialBalance}');
    _storageService = SvStorageService(Get.find<SharedPreferencesService>());
    _balanceController.addListener(_onBalanceChanged);
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
    _balanceController.removeListener(_onBalanceChanged);
    _balanceController.dispose();
    _balanceFocusNode.dispose();
    super.dispose();
  }

  void _onBalanceChanged() {
    setState(() {});
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

  Future<double?> _autoSaveBalance({bool requirePositive = false}) async {
    final balanceText = _balanceController.text.trim();

    if (balanceText.isEmpty) {
      await _storageService.clearBalance();
      setState(() {
        _savedBalance = null;
      });
      if (requirePositive) {
        if (mounted) {
          SvDialogUtil.showErrorDialog(context, '請輸入有效的金額');
        }
        return null;
      }
      return null;
    }

    final balance = double.tryParse(balanceText);
    if (balance == null || balance < 0) {
      if (mounted) {
        SvDialogUtil.showErrorDialog(context, '請輸入有效的金額');
      }
      return null;
    }

    if (requirePositive && balance <= 0) {
      if (mounted) {
        SvDialogUtil.showErrorDialog(context, '請輸入大於 0 的金額');
      }
      return null;
    }

    await _storageService.saveBalance(balance);
    setState(() {
      _savedBalance = balance;
    });
    return balance;
  }

  Future<void> _onMapQueryTap() async {
    final balance = await _autoSaveBalance();
    if (!mounted) return;
    SvNavigatorUtil.toMap(balance: balance ?? _savedBalance);
  }

  Future<void> _onTextSearchTap() async {
    final balance = await _autoSaveBalance();
    if (!mounted) return;
    SvNavigatorUtil.toTextSearch(balance: balance ?? _savedBalance);
  }

  Future<void> _onMatchTap() async {
    final balance = await _autoSaveBalance(requirePositive: true);
    if (!mounted || balance == null) return;
    SvNavigatorUtil.toMatch(balance: balance);
  }

  Future<void> _clearAllData() async {
    final confirmed = await SvDialogUtil.showConfirmDialog(
      context,
      '確定要清除所有資料嗎？\n這將清除餘額、Like 清單和推薦權重。',
      title: '清除資料',
      confirmText: '清除',
      cancelText: '取消',
    );

    if (confirmed && mounted) {
      await _storageService.clearAllData();
      setState(() {
        _savedBalance = null;
        _balanceController.clear();
      });

      if (mounted) {
        Get.snackbar(
          '成功',
          '所有資料已清除',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: TPColors.primary500,
          colorText: TPColors.white,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] SvHomePage.build called');
    return Scaffold(
      backgroundColor: TPColors.primary50,
      appBar: const TPAppBar(
        title: '動滋券查詢',
        backgroundColor: TPColors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBanner(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildBalanceInputCard(),
            ),
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
                  Builder(
                    builder: (context) {
                      final typedBalance = double.tryParse(_balanceController.text.trim());
                      final effectiveBalance = _savedBalance ?? typedBalance;
                      final canMatch = (effectiveBalance ?? 0) > 0;

                      return Row(
                        children: [
                          Expanded(
                            child: _buildServiceCard(
                              icon: Assets.svg.iconLocationSearch24.svg(),
                              title: '地圖查詢',
                              description: '查看店家位置',
                              onTap: _onMapQueryTap,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildServiceCard(
                              icon: Assets.svg.iconCaseSearch.svg(),
                              title: '文字搜尋',
                              description: '搜尋店家名稱',
                              onTap: _onTextSearchTap,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildServiceCard(
                              icon: Icon(
                                Icons.favorite,
                                size: 40,
                                color: canMatch ? TPColors.primary500 : TPColors.grayscale400,
                              ),
                              title: '餘額配對',
                              description: '滑動配對店家',
                              onTap: canMatch ? _onMatchTap : null,
                              isEnabled: canMatch,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildOfficialWebsiteCard(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildClearDataCard(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 180,
            viewportFraction: 1.0,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 5),
            onPageChanged: (index, reason) {
              setState(() {
                _currentBannerIndex = index;
              });
            },
          ),
          items: _bannerImages.map((imagePath) {
            return Builder(
              builder: (context) {
                return Container(
                  width: double.infinity,
                  color: TPColors.primary100,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          'Banner 圖片',
                          style: TPTextStyles.bodyRegular.copyWith(
                            color: TPColors.grayscale600,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_bannerImages.length, (index) {
            final isActive = index == _currentBannerIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? TPColors.primary500 : TPColors.grayscale300,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBalanceInputCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
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
            boxShadow: const [
              BoxShadow(
                color: TPColors.grayscale100,
                blurRadius: 8,
                offset: Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 40, height: 40, child: icon),
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
          boxShadow: const [
            BoxShadow(
              color: TPColors.grayscale100,
              blurRadius: 8,
              offset: Offset(0, 2),
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
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: TPColors.grayscale400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearDataCard() {
    return GestureDetector(
      onTap: _clearAllData,
      child: Container(
        decoration: BoxDecoration(
          color: TPColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: TPColors.grayscale200,
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: TPColors.grayscale100,
              blurRadius: 8,
              offset: Offset(0, 2),
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
                color: TPColors.grayscale100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: TPColors.grayscale200,
                  width: 1,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.refresh,
                  size: 24,
                  color: TPColors.grayscale600,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '清除所有資料',
                    style: TPTextStyles.h3SemiBold.copyWith(
                      color: TPColors.grayscale900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '重置餘額、Like 清單和推薦權重',
                    style: TPTextStyles.caption.copyWith(
                      color: TPColors.grayscale700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
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
