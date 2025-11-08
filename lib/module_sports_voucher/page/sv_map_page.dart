import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
import 'package:town_pass/util/tp_button.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_text.dart';
import 'package:town_pass/util/tp_text_styles.dart';

/// 動茲券地圖查詢頁
class SvMapPage extends StatefulWidget {
  const SvMapPage({super.key});

  @override
  State<SvMapPage> createState() => _SvMapPageState();
}

class _SvMapPageState extends State<SvMapPage> {
  final SvApiService _apiService = SvApiService();
  late final SvLocationService _locationService;
  late final SvStorageService _storageService;
  
  GoogleMapController? _mapController;
  Position? _userPosition;
  List<SvMerchant> _allMerchants = [];
  List<SvMerchant> _displayedMerchants = [];
  Set<Marker> _markers = {};
  SvMerchant? _selectedMerchant;
  String _filterMode = 'all'; // 'all', 'affordable', 'liked'
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    _balance = args?['balance'] ?? 0.0;
    
    _locationService = SvLocationService(Get.find<GeoLocatorService>());
    _storageService = SvStorageService(Get.find<SharedPreferencesService>());
    
    _loadData();
  }

  Future<void> _loadData() async {
    SvDialogUtil.showLoadingDialog(context);
    try {
      // 取得使用者位置
      _userPosition = await _locationService.getCurrentPosition();
      
      // 取得所有店家
      _allMerchants = await _apiService.fetchMerchants();
      
      // 根據篩選模式顯示店家
      _updateDisplayedMerchants();
      
      // 更新地圖標記
      _updateMarkers();
      
      // 移動地圖到使用者位置
      if (_mapController != null && _userPosition != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(_userPosition!.latitude, _userPosition!.longitude),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SvDialogUtil.dismissDialog(context);
        SvDialogUtil.showErrorDialog(context, '載入資料失敗：$e');
      }
    } finally {
      if (mounted) {
        SvDialogUtil.dismissDialog(context);
      }
    }
  }

  void _updateDisplayedMerchants() {
    setState(() {
      switch (_filterMode) {
        case 'affordable':
          _displayedMerchants = _allMerchants.where((m) => m.isAffordable(_balance)).toList();
          break;
        case 'liked':
          _loadLikedMerchants();
          break;
        default:
          _displayedMerchants = _allMerchants;
      }
    });
  }

  Future<void> _loadLikedMerchants() async {
    final likedIds = await _storageService.getLikes();
    _displayedMerchants = _allMerchants.where((m) => likedIds.contains(m.id)).toList();
  }

  void _updateMarkers() {
    _markers = _displayedMerchants.map((merchant) {
      return Marker(
        markerId: MarkerId(merchant.id.toString()),
        position: LatLng(merchant.lat, merchant.lng),
        infoWindow: InfoWindow(
          title: merchant.name,
          snippet: '最低消費：${SvFormatter.formatCurrency(merchant.minSpend)}',
        ),
        onTap: () => _onMarkerTapped(merchant),
      );
    }).toSet();
    
    setState(() {});
  }

  void _onMarkerTapped(SvMerchant merchant) {
    setState(() {
      _selectedMerchant = merchant;
    });
  }

  void _onFilterChanged(String mode) {
    setState(() {
      _filterMode = mode;
      _selectedMerchant = null;
    });
    _updateDisplayedMerchants();
    _updateMarkers();
  }

  Future<void> _toggleLike(SvMerchant merchant) async {
    final isLiked = await _storageService.isLiked(merchant.id);
    if (isLiked) {
      await _storageService.removeLike(merchant.id);
    } else {
      await _storageService.addLike(merchant.id);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TPAppBar(
        title: '地圖查詢',
        backgroundColor: TPColors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userPosition != null
                  ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                  : const LatLng(25.0330, 121.5654), // 台北市預設位置
              zoom: 13,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_userPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLng(
                    LatLng(_userPosition!.latitude, _userPosition!.longitude),
                  ),
                );
              }
            },
          ),
          // 篩選按鈕
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TPColors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: TPColors.grayscale950.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFilterChip('all', '全部'),
                  const SizedBox(width: 8),
                  _buildFilterChip('affordable', '可用'),
                  const SizedBox(width: 8),
                  _buildFilterChip('liked', '收藏'),
                ],
              ),
            ),
          ),
          // 店家資訊卡
          if (_selectedMerchant != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildMerchantCard(_selectedMerchant!),
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
    return FutureBuilder<bool>(
      future: _storageService.isLiked(merchant.id),
      builder: (context, snapshot) {
        final isLiked = snapshot.data ?? false;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TPColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: TPColors.grayscale950.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Text(
                '最低消費：${SvFormatter.formatCurrency(merchant.minSpend)}',
                style: TPTextStyles.bodySemiBold.copyWith(color: TPColors.primary500),
              ),
              if (merchant.phone != null) ...[
                const SizedBox(height: 8),
                Text(
                  '電話：${merchant.phone}',
                  style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TPButton.secondary(
                      text: '關閉',
                      onPressed: () {
                        setState(() {
                          _selectedMerchant = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TPButton.primary(
                      text: '導航',
                      onPressed: () {
                        // 開啟導航功能
                        // 可以使用 url_launcher 開啟 Google Maps 導航
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

