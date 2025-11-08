import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/module_sports_voucher/bean/sv_merchant.dart';
import 'package:town_pass/module_sports_voucher/service/sv_api_service.dart';
import 'package:town_pass/module_sports_voucher/service/sv_storage_service.dart';
import 'package:town_pass/module_sports_voucher/util/sv_dialog_util.dart';
import 'package:town_pass/module_sports_voucher/util/sv_formatter.dart';
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

class _SvMatchPageState extends State<SvMatchPage> {
  final SvApiService _apiService = SvApiService();
  late final SvStorageService _storageService;
  
  List<SvMerchant> _merchants = [];
  int _currentIndex = 0;
  double _balance = 0;
  bool _isLoading = true;
  
  double _dragPosition = 0.0;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    _balance = args?['balance'] ?? 0.0;
    
    _storageService = SvStorageService(Get.find<SharedPreferencesService>());
    
    _loadData();
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
      // 取得可用店家
      _merchants = await _apiService.fetchAffordableMerchants(_balance);
      
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
    // Skip
    _nextCard();
  }

  void _onSwipeRight() async {
    // Like
    if (_currentIndex < _merchants.length) {
      final merchant = _merchants[_currentIndex];
      await _storageService.addLike(merchant.id);
      _nextCard();
    }
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
    setState(() {
      _dragPosition += details.delta.dx;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    
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
          title: '配對推薦',
          backgroundColor: TPColors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_merchants.isEmpty) {
      return Scaffold(
        appBar: TPAppBar(
          title: '配對推薦',
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
          title: '配對推薦',
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
        title: '配對推薦',
        backgroundColor: TPColors.white,
      ),
      body: Stack(
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
            child: GestureDetector(
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Transform.translate(
                  offset: Offset(_dragPosition, 0),
                  child: Transform.rotate(
                    angle: _dragPosition * 0.001,
                    child: _buildCard(currentMerchant),
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
    );
  }

  Widget _buildCard(SvMerchant merchant, {bool isNext = false}) {
    return Card(
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

