import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:town_pass/module_sports_voucher/bean/sv_merchant.dart';
import 'package:town_pass/module_sports_voucher/service/sv_api_service.dart';
import 'package:town_pass/module_sports_voucher/service/sv_location_service.dart';
import 'package:town_pass/module_sports_voucher/service/sv_storage_service.dart';
import 'package:town_pass/module_sports_voucher/util/sv_dialog_util.dart';
import 'package:town_pass/module_sports_voucher/util/sv_formatter.dart';
import 'package:town_pass/service/geo_locator_service.dart';
import 'package:town_pass/service/shared_preferences_service.dart';
import 'package:town_pass/util/tp_app_bar.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_text.dart';
import 'package:town_pass/util/tp_text_styles.dart';

/// 動滋券配對頁（Tinder 式滑動介面）
class SvMatchPage extends StatefulWidget {
  const SvMatchPage({super.key});

  @override
  State<SvMatchPage> createState() => _SvMatchPageState();
}

class _SvMatchPageState extends State<SvMatchPage> with SingleTickerProviderStateMixin {
  final SvApiService _apiService = SvApiService();
  late final SvStorageService _storageService;
  late final SvLocationService _locationService;
  
  List<SvMerchant> _merchants = [];
  int _currentIndex = 0;
  double? _balance;
  bool _isLoading = true;
  Position? _userPosition;
  
  double _dragPosition = 0.0;
  bool _isSwiping = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    _balance = args?['balance'];
    
    _storageService = SvStorageService(Get.find<SharedPreferencesService>());
    _locationService = SvLocationService(Get.find<GeoLocatorService>());
    
    _loadBalance();
    _loadData();
  }

  Future<void> _loadBalance() async {
    final savedBalance = await _storageService.getBalance();
    if (mounted) {
      setState(() {
        _balance = _balance ?? savedBalance;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // 取得使用者位置
      _userPosition = await _locationService.getCurrentPosition();
      
      // 取得可用店家
      if (_balance != null && _balance! > 0) {
        _merchants = await _apiService.fetchAffordableMerchants(_balance!);
      } else {
        _merchants = await _apiService.fetchMerchants();
      }
      
      if (_merchants.isEmpty) {
        if (mounted) {
          SvDialogUtil.showErrorDialog(
            context,
            '沒有找到可用動滋券消費的店家',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SvDialogUtil.showErrorDialog(context, '載入資料失敗：$e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSwipeLeft() {
    // Skip - 左滑動畫
    if (_currentIndex < _merchants.length) {
      _swipeCard(-1);
    }
  }

  void _onSwipeRight() async {
    // Like - 右滑動畫
    if (_currentIndex < _merchants.length) {
      final merchant = _merchants[_currentIndex];
      await _storageService.addLike(merchant.id);
      _swipeCard(1);
    }
  }

  void _swipeCard(int direction) {
    setState(() {
      _isSwiping = true;
    });

    // 動畫滑動卡片
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _nextCard();
        setState(() {
          _isSwiping = false;
          _dragPosition = 0.0;
        });
      }
    });
  }

  void _nextCard() {
    if (_currentIndex < _merchants.length - 1) {
      setState(() {
        _currentIndex++;
        _dragPosition = 0.0;
      });
    } else {
      // 沒有更多卡片
      SvDialogUtil.showErrorDialog(context, '已經瀏覽完所有店家了！');
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isSwiping) {
      setState(() {
        _dragPosition += details.delta.dx;
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isSwiping) return;
    
    const swipeThreshold = 100.0;
    
    if (_dragPosition > swipeThreshold) {
      // 右滑 - Like
      _onSwipeRight();
    } else if (_dragPosition < -swipeThreshold) {
      // 左滑 - Skip
      _onSwipeLeft();
    } else {
      // 回到原位
      setState(() {
        _dragPosition = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: TPAppBar(
          title: '餘額配對',
          backgroundColor: TPColors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_merchants.isEmpty) {
      return Scaffold(
        appBar: TPAppBar(
          title: '餘額配對',
          backgroundColor: TPColors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '沒有找到可用動滋券消費的店家',
                style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale500),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Get.back(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentIndex >= _merchants.length) {
      return Scaffold(
        appBar: TPAppBar(
          title: '餘額配對',
          backgroundColor: TPColors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '已經瀏覽完所有店家了！',
                style: TPTextStyles.h2SemiBold.copyWith(color: TPColors.grayscale950),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Get.back(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    final currentMerchant = _merchants[_currentIndex];
    final nextMerchant = _currentIndex < _merchants.length - 1
        ? _merchants[_currentIndex + 1]
        : null;

    return Scaffold(
      appBar: TPAppBar(
        title: '餘額配對',
        backgroundColor: TPColors.white,
      ),
      body: Column(
        children: [
          // 餘額提示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: TPColors.primary50,
            child: Row(
              children: [
                Icon(
                  _balance != null ? Icons.account_balance_wallet : Icons.warning_amber_rounded,
                  size: 20,
                  color: _balance != null ? TPColors.primary500 : TPColors.grayscale600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _balance != null
                        ? '目前餘額：${SvFormatter.formatCurrency(_balance!)}'
                        : '⚠️ 尚未儲存餘額，僅供瀏覽查詢。',
                    style: TPTextStyles.bodyRegular.copyWith(
                      color: _balance != null ? TPColors.primary600 : TPColors.grayscale600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 卡片區域
          Expanded(
            child: Stack(
              children: [
          // 下一張卡片（背景）
          if (nextMerchant != null)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildCard(nextMerchant, isNext: true),
              ),
            ),
          // 當前卡片
          Positioned.fill(
            child: AnimatedContainer(
              duration: _isSwiping ? const Duration(milliseconds: 300) : Duration.zero,
              curve: Curves.easeOut,
              child: GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Transform.translate(
                    offset: Offset(_isSwiping ? (_dragPosition > 0 ? 1000 : -1000) : _dragPosition, 0),
                    child: Transform.rotate(
                      angle: _dragPosition * 0.001,
                      child: Opacity(
                        opacity: _isSwiping ? 0.0 : 1.0,
                        child: _buildCard(currentMerchant),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 操作按鈕
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Skip 按鈕
                _buildActionButton(
                  icon: Icons.close,
                  color: TPColors.grayscale400,
                  onPressed: _onSwipeLeft,
                ),
                const SizedBox(width: 24),
                // Like 按鈕
                _buildActionButton(
                  icon: Icons.favorite,
                  color: TPColors.red500,
                  onPressed: _onSwipeRight,
                ),
              ],
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(SvMerchant merchant, {bool isNext = false}) {
    // 計算距離
    double? distance;
    if (_userPosition != null) {
      distance = _locationService.calculateDistance(
        _userPosition!.latitude,
        _userPosition!.longitude,
        merchant.lat,
        merchant.lng,
      );
    }

    return GestureDetector(
      onTap: () => _showMerchantDetail(merchant),
      child: Card(
        elevation: isNext ? 2 : 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                TPColors.primary100,
                TPColors.white,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 圖片區域（模擬）
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  color: TPColors.primary200,
                ),
                child: Center(
                  child: Icon(
                    Icons.store,
                    size: 80,
                    color: TPColors.primary600,
                  ),
                ),
              ),
              // 資訊區域
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.name,
                      style: TPTextStyles.h1SemiBold.copyWith(color: TPColors.grayscale950),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: TPColors.grayscale600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            merchant.address,
                            style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
                          ),
                        ),
                      ],
                    ),
                    if (merchant.businessHours != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: TPColors.grayscale600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              merchant.businessHours!,
                              style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (distance != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.straighten, size: 16, color: TPColors.grayscale600),
                          const SizedBox(width: 4),
                          Text(
                            SvFormatter.formatDistance(distance),
                            style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: TPColors.primary500,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '最低消費：${SvFormatter.formatCurrency(merchant.minSpend)}',
                        style: TPTextStyles.bodySemiBold.copyWith(color: TPColors.white),
                      ),
                    ),
                    if (merchant.description != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        merchant.description!,
                        style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMerchantDetail(SvMerchant merchant) {
    // 使用與文字搜尋頁相同的詳情彈窗
    // 這裡可以重用相同的邏輯，或直接導航到詳情頁
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: TPColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: TPColors.grayscale300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      merchant.name,
                      style: TPTextStyles.h2SemiBold.copyWith(color: TPColors.grayscale950),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      icon: Icons.location_on,
                      label: '地址',
                      value: merchant.address,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      icon: Icons.payment,
                      label: '最低消費',
                      value: SvFormatter.formatCurrency(merchant.minSpend),
                    ),
                    if (merchant.businessHours != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: Icons.access_time,
                        label: '營業時間',
                        value: merchant.businessHours!,
                      ),
                    ],
                    if (_userPosition != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: Icons.straighten,
                        label: '距離',
                        value: SvFormatter.formatDistance(
                          _locationService.calculateDistance(
                            _userPosition!.latitude,
                            _userPosition!.longitude,
                            merchant.lat,
                            merchant.lng,
                          ),
                        ),
                      ),
                    ],
                    if (merchant.phone != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: Icons.phone,
                        label: '電話',
                        value: merchant.phone!,
                      ),
                    ],
                    if (merchant.category != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: Icons.category,
                        label: '分類',
                        value: merchant.category!,
                      ),
                    ],
                    if (merchant.website != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: Icons.language,
                        label: '網站',
                        value: merchant.website!,
                      ),
                    ],
                    if (merchant.description != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        '描述',
                        style: TPTextStyles.bodySemiBold.copyWith(color: TPColors.grayscale900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        merchant.description!,
                        style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: TPColors.primary500),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TPTextStyles.bodySemiBold.copyWith(color: TPColors.grayscale900),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: TPColors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 32),
        onPressed: onPressed,
      ),
    );
  }
}

