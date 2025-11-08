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

/// 動茲券文字搜尋頁
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
  List<int> _likedIds = [];
  String _filterMode = 'all'; // 'all', 'affordable', 'liked'
  double? _balance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    _balance = args?['balance'];
    
    _storageService = SvStorageService(Get.find<SharedPreferencesService>());
    
    _loadData();
    _searchController.addListener(_onSearchChanged);
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
      _allMerchants = await _apiService.fetchMerchants();
      _likedIds = await _storageService.getLikes();
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
      
      List<SvMerchant> filtered = _allMerchants;
      
      // 根據篩選模式過濾
      switch (_filterMode) {
        case 'affordable':
          if (_balance != null) {
            filtered = filtered.where((m) => m.isAffordable(_balance!)).toList();
          }
          break;
        case 'liked':
          filtered = filtered.where((m) => _likedIds.contains(m.id)).toList();
          break;
        default:
          break;
      }
      
      // 根據搜尋關鍵字過濾
      if (searchQuery.isNotEmpty) {
        filtered = filtered.where((merchant) {
          return merchant.name.toLowerCase().contains(searchQuery) ||
              merchant.address.toLowerCase().contains(searchQuery);
        }).toList();
      }
      
      _displayedMerchants = filtered;
    });
  }

  void _onFilterChanged(String mode) {
    setState(() {
      _filterMode = mode;
    });
    _updateDisplayedMerchants();
  }

  Future<void> _toggleLike(SvMerchant merchant) async {
    final isLiked = _likedIds.contains(merchant.id);
    if (isLiked) {
      await _storageService.removeLike(merchant.id);
    } else {
      await _storageService.addLike(merchant.id);
    }
    _likedIds = await _storageService.getLikes();
    setState(() {});
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
          // 搜尋欄
          Container(
            padding: const EdgeInsets.all(16),
            color: TPColors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜尋店家名稱或地址',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: TPColors.grayscale50,
                  ),
                  style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale950),
                ),
                const SizedBox(height: 12),
                // 篩選按鈕
                Row(
                  children: [
                    _buildFilterChip('all', '全部'),
                    const SizedBox(width: 8),
                    if (_balance != null)
                      _buildFilterChip('affordable', '可用'),
                    if (_balance != null) const SizedBox(width: 8),
                    _buildFilterChip('liked', '收藏'),
                  ],
                ),
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

  Widget _buildFilterChip(String mode, String label) {
    final isSelected = _filterMode == mode;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _onFilterChanged(mode);
        }
      },
      selectedColor: TPColors.primary500,
      labelStyle: TPTextStyles.bodyRegular.copyWith(
        color: isSelected ? TPColors.white : TPColors.grayscale700,
      ),
    );
  }

  Widget _buildMerchantCard(SvMerchant merchant) {
    final isLiked = _likedIds.contains(merchant.id);
    final isAffordable = _balance != null && merchant.isAffordable(_balance!);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // 可以開啟店家詳情頁面
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
              Text(
                merchant.address,
                style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '最低消費：${SvFormatter.formatCurrency(merchant.minSpend)}',
                    style: TPTextStyles.bodySemiBold.copyWith(color: TPColors.primary500),
                  ),
                  if (isAffordable) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: TPColors.primary50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '可用',
                        style: TPTextStyles.caption.copyWith(color: TPColors.primary600),
                      ),
                    ),
                  ],
                ],
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
}

