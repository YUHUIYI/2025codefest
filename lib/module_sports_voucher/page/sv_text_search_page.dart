import 'dart:math' as math;

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
import 'package:town_pass/util/tp_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

/// 動滋券文字搜尋頁
class SvTextSearchPage extends StatefulWidget {
  const SvTextSearchPage({super.key});

  @override
  State<SvTextSearchPage> createState() => _SvTextSearchPageState();
}

class _SvTextSearchPageState extends State<SvTextSearchPage> {
  final SvApiService _apiService = SvApiService();
  late final SvStorageService _storageService;
  
  final TextEditingController _searchController = TextEditingController();
  List<SvMerchant> _allMerchants = [];
  List<SvMerchant> _displayedMerchants = [];
  List<String> _likedIds = [];
  Map<String, List<Map<String, dynamic>>> _storeProducts = {};
  bool _showFavoritesOnly = false;
  double _priceSliderMax = 1000;
  double _priceSliderValue = 1000;
  double? _balance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    _balance = args?['balance'];
    
    _storageService = SvStorageService(Get.find<SharedPreferencesService>());
    
    _loadBalance();
    _loadData();
    _searchController.addListener(_onSearchChanged);
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final merchants = await _apiService.fetchMerchants();
      final likedIds = await _storageService.getLikes();
      final storeProducts = await _apiService.fetchStoreProducts();
      final priceMax = _calculatePriceSliderMax(merchants, storeProducts);

      if (!mounted) {
        return;
      }

      setState(() {
        _allMerchants = merchants;
        _likedIds = likedIds;
        _storeProducts = storeProducts;
        _priceSliderMax = priceMax;
        _priceSliderValue = priceMax;
      });
      _updateDisplayedMerchants();
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

  void _onSearchChanged() {
    _updateDisplayedMerchants();
  }

  void _updateDisplayedMerchants() {
    setState(() {
      String searchQuery = _searchController.text.toLowerCase().trim();

      List<SvMerchant> filtered = List<SvMerchant>.from(_allMerchants);

      if (_showFavoritesOnly) {
        filtered = filtered.where((merchant) => _likedIds.contains(merchant.id)).toList();
      }

      final hasPriceFilter =
          _priceSliderMax > 0 && (_priceSliderMax - _priceSliderValue).abs() > 0.1;
      if (hasPriceFilter) {
        filtered = filtered.where((merchant) {
          final price = _getEffectiveMinPrice(merchant);
          return price <= _priceSliderValue;
        }).toList();
      }

      if (searchQuery.isNotEmpty) {
        filtered = filtered.where((merchant) {
          final nameMatch = merchant.name.toLowerCase().contains(searchQuery);

          if (nameMatch) {
            return true;
          }

          final products = _storeProducts[merchant.id] ?? [];
          final productMatch = products.any((product) {
            final productName = product['product_name'];
            return productName != null &&
                productName.toString().toLowerCase().contains(searchQuery);
          });

          return productMatch;
        }).toList();
      }

      _displayedMerchants = filtered;
    });
  }

  Future<void> _toggleLike(SvMerchant merchant) async {
    final isLiked = _likedIds.contains(merchant.id);
    if (isLiked) {
      await _storageService.removeLike(merchant.id);
    } else {
      await _storageService.addLike(merchant.id);
    }
    _likedIds = await _storageService.getLikes();
    _updateDisplayedMerchants();
  }

  void _showMerchantDetail(SvMerchant merchant) {
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
            // 拖曳指示器
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: TPColors.grayscale300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 標題列
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
                    icon: Icon(
                      _likedIds.contains(merchant.id) ? Icons.favorite : Icons.favorite_border,
                      color: _likedIds.contains(merchant.id) ? TPColors.red500 : TPColors.grayscale400,
                    ),
                    onPressed: () => _toggleLike(merchant),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // 內容
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 地址
                    _buildDetailRow(
                      icon: Icons.location_on,
                      label: '地址',
                      value: merchant.address,
                      onTap: merchant.address.isNotEmpty
                          ? () => _launchGoogleMaps(merchant.address)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // 商品列表
                    _buildProductsSection(merchant),
                    if (merchant.phone != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: Icons.phone,
                        label: '電話',
                        value: merchant.phone!,
                      ),
                    ],
                    if (merchant.businessHours != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: Icons.access_time,
                        label: '營業時間',
                        value: merchant.businessHours!,
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
                    if (merchant.updatedAt != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: Icons.update,
                        label: '更新時間',
                        value: SvFormatter.formatDateTime(merchant.updatedAt!),
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
    VoidCallback? onTap,
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
              onTap != null
                  ? InkWell(
                      onTap: onTap,
                      child: Text(
                        value,
                        style: TPTextStyles.bodyRegular.copyWith(
                          color: TPColors.primary600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    )
                  : Text(
                      value,
                      style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TPAppBar(
        title: '文字搜尋',
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
                        ? '💰 目前餘額：${SvFormatter.formatCurrency(_balance!)}'
                        : '⚠️ 尚未儲存餘額，僅供瀏覽查詢。',
                    style: TPTextStyles.bodyRegular.copyWith(
                      color: _balance != null ? TPColors.primary600 : TPColors.grayscale600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 搜尋欄
          Container(
            padding: const EdgeInsets.all(16),
            color: TPColors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜尋店家名稱或商品名稱',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: TPColors.grayscale50,
                    ),
                    style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale950),
                  ),
                ),
                const SizedBox(width: 12),
                _buildFilterButton(),
              ],
            ),
          ),
          // 店家列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _displayedMerchants.isEmpty
                    ? Center(
                        child: Text(
                          '沒有找到符合條件的店家',
                          style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale500),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _displayedMerchants.length,
                        itemBuilder: (context, index) {
                          final merchant = _displayedMerchants[index];
                          return _buildMerchantCard(merchant);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantCard(SvMerchant merchant) {
    final isLiked = _likedIds.contains(merchant.id);
    final products = _storeProducts[merchant.id] ?? [];
    final minPrice = _getStoreMinPrice(products) ?? merchant.minSpend;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _showMerchantDetail(merchant);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      merchant.name,
                      style: TPTextStyles.h3SemiBold.copyWith(color: TPColors.grayscale950),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? TPColors.red500 : TPColors.grayscale400,
                    ),
                    onPressed: () => _toggleLike(merchant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (merchant.address.isNotEmpty)
                InkWell(
                  onTap: () => _launchGoogleMaps(merchant.address),
                  child: Text(
                    merchant.address,
                    style: TPTextStyles.bodyRegular.copyWith(
                      color: TPColors.primary600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              else
                Text(
                  '暫無地址資訊',
                  style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale500),
                ),
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              Text(
                '最低消費：${SvFormatter.formatCurrency(minPrice)}',
                style: TPTextStyles.bodySemiBold.copyWith(color: TPColors.primary500),
              ),
              if (merchant.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  merchant.description!,
                  style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton() {
    final hasActiveFilter = _showFavoritesOnly ||
        (_priceSliderMax > 0 && (_priceSliderMax - _priceSliderValue).abs() > 0.1);

    return InkWell(
      onTap: _showFilterSheet,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: hasActiveFilter ? TPColors.primary500 : TPColors.primary200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.tune,
          color: TPColors.white,
        ),
      ),
    );
  }

  Widget _buildProductsSection(SvMerchant merchant) {
    final products = _storeProducts[merchant.id] ?? [];

    if (products.isEmpty) {
      return _buildDetailRow(
        icon: Icons.shopping_bag,
        label: '商品',
        value: '目前無商品資訊',
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shopping_bag, size: 20, color: TPColors.primary500),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '商品',
                style: TPTextStyles.bodySemiBold.copyWith(color: TPColors.grayscale900),
              ),
              const SizedBox(height: 8),
              ...products.map((product) {
                final productName = product['product_name']?.toString() ?? '未命名商品';
                final priceText = _formatPrice(product['price']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          productName,
                          style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
                        ),
                      ),
                      Text(
                        priceText,
                        style: TPTextStyles.bodyRegular.copyWith(color: TPColors.primary600),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchGoogleMaps(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        SvDialogUtil.showErrorDialog(context, '無法開啟 Google Maps');
      }
    }
  }

  Future<void> _showFilterSheet() async {
    bool tempFavorites = _showFavoritesOnly;
    double tempPrice = _priceSliderValue.clamp(0, _priceSliderMax).toDouble();

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final isUnlimited =
                (tempPrice - _priceSliderMax).abs() <= 0.1 || _priceSliderMax == 0;
            final priceLabel =
                isUnlimited ? '不限' : SvFormatter.formatCurrency(tempPrice);

            final divisions =
                _priceSliderMax > 0 ? math.max(1, (_priceSliderMax ~/ 100)) : 1;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: 20 + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: TPColors.grayscale300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '篩選',
                    style: TPTextStyles.h2SemiBold.copyWith(
                      color: TPColors.grayscale950,
                    ),
                  ),
                  const SizedBox(height: 24),
                  CheckboxListTile(
                    value: tempFavorites,
                    onChanged: (value) {
                      setStateModal(() {
                        tempFavorites = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '只顯示收藏',
                      style: TPTextStyles.bodySemiBold.copyWith(
                        color: TPColors.grayscale900,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: TPColors.primary500,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '價格上限',
                    style: TPTextStyles.bodySemiBold.copyWith(
                      color: TPColors.grayscale900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'NT\$0',
                        style: TPTextStyles.bodyRegular.copyWith(
                          color: TPColors.grayscale500,
                        ),
                      ),
                      Text(
                        priceLabel,
                        style: TPTextStyles.bodySemiBold.copyWith(
                          color: TPColors.primary600,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: tempPrice,
                    min: 0,
                    max: _priceSliderMax,
                    divisions: divisions.toInt(),
                    label: priceLabel,
                    onChanged: (value) {
                      setStateModal(() {
                        tempPrice = value;
                      });
                    },
                    activeColor: TPColors.primary500,
                    inactiveColor: TPColors.primary100,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: TPColors.grayscale700,
                            side: const BorderSide(color: TPColors.grayscale200),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop({
                              'favorites': tempFavorites,
                              'price': tempPrice,
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TPColors.primary500,
                            foregroundColor: TPColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('套用'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _showFavoritesOnly = result['favorites'] as bool? ?? false;
        final priceValue = (result['price'] as double?) ?? _priceSliderMax;
        _priceSliderValue = priceValue.clamp(0, _priceSliderMax).toDouble();
      });
      _updateDisplayedMerchants();
    }
  }

  double _getEffectiveMinPrice(SvMerchant merchant) {
    final products = _storeProducts[merchant.id] ?? [];
    return _getStoreMinPrice(products) ?? merchant.minSpend;
  }

  double _calculatePriceSliderMax(
    List<SvMerchant> merchants,
    Map<String, List<Map<String, dynamic>>> storeProducts,
  ) {
    double maxPrice = 0;

    for (final merchant in merchants) {
      final products = storeProducts[merchant.id] ?? [];
      final price = _getStoreMinPrice(products) ?? merchant.minSpend;
      if (price > maxPrice) {
        maxPrice = price;
      }
    }

    if (maxPrice <= 0) {
      return 1000;
    }

    final rounded = (maxPrice / 100).ceil() * 100;
    return math.max(rounded.toDouble(), 100);
  }

  double? _getStoreMinPrice(List<Map<String, dynamic>> products) {
    double? minPrice;

    for (final product in products) {
      final price = product['price'];
      final priceValue = price is num
          ? price.toDouble()
          : price is String
              ? double.tryParse(price)
              : null;

      if (priceValue != null && priceValue > 0) {
        if (minPrice == null || priceValue < minPrice) {
          minPrice = priceValue;
        }
      }
    }

    return minPrice;
  }

  String _formatPrice(dynamic price) {
    if (price is num) {
      return SvFormatter.formatCurrency(price.toDouble());
    }
    if (price is String) {
      final parsed = double.tryParse(price);
      if (parsed != null) {
        return SvFormatter.formatCurrency(parsed);
      }
    }
    return '—';
  }
}

