import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
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
import 'package:town_pass/util/tp_text_styles.dart';

/// 動滋券地圖查詢頁
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
  Set<Marker> _markers = {};
  SvMerchant? _selectedMerchant;
  SvMerchant? _lastClickedMerchant;
  double _balance = 0;
  bool _showDetail = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    _balance = args?['balance'] ?? 0.0;
    
    _locationService = SvLocationService(Get.find<GeoLocatorService>());
    _storageService = SvStorageService(Get.find<SharedPreferencesService>());
    
    _loadBalance();
    
    // 延遲到 widget 完全初始化後再載入資料
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadBalance() async {
    final savedBalance = await _storageService.getBalance();
    if (mounted) {
      setState(() {
        _balance = _balance > 0 ? _balance : (savedBalance ?? 0.0);
      });
    }
  }

  Future<void> _loadData() async {
    SvDialogUtil.showLoadingDialog(context);
    try {
      // 取得使用者位置
      _userPosition = await _locationService.getCurrentPosition();
      
      // 取得所有店家
      _allMerchants = await _apiService.fetchMerchants();
      
      // 檢查是否有店家資料
      if (_allMerchants.isEmpty) {
        if (mounted) {
          SvDialogUtil.dismissDialog(context);
          SvDialogUtil.showErrorDialog(context, '無法取得店家資料，請檢查網路連線或稍後再試');
        }
        return;
      }
      
      // 過濾掉座標無效的店家（0,0 或 geocoding 失敗）
      final validMerchants = _allMerchants.where((m) => m.lat != 0.0 && m.lng != 0.0).toList();
      
      if (validMerchants.isEmpty) {
        if (mounted) {
          SvDialogUtil.dismissDialog(context);
          SvDialogUtil.showErrorDialog(context, '所有店家的地址都無法轉換為座標，請稍後再試');
        }
        return;
      }
      
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

  void _updateMarkers() {
    // 只顯示有效座標的店家標記
    _markers = _allMerchants
        .where((merchant) => merchant.lat != 0.0 && merchant.lng != 0.0)
        .map((merchant) {
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
      if (_selectedMerchant?.id == merchant.id && _lastClickedMerchant?.id == merchant.id) {
        // 再次點擊相同地點，顯示詳細資料
        _showDetail = true;
      } else {
        // 第一次點擊，顯示資訊卡
        _selectedMerchant = merchant;
        _lastClickedMerchant = merchant;
        _showDetail = false;
      }
    });
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

  Future<void> _openGoogleMaps(SvMerchant merchant) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(merchant.address)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        SvDialogUtil.showErrorDialog(context, '無法開啟 Google Maps');
      }
    }
  }

  void _closeInfoCard() {
    setState(() {
      _selectedMerchant = null;
      _lastClickedMerchant = null;
      _showDetail = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TPAppBar(
        title: '地圖查詢',
        backgroundColor: TPColors.white,
        actions: [
          if (_balance > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  SvFormatter.formatCurrency(_balance),
                  style: TPTextStyles.bodySemiBold.copyWith(
                    color: TPColors.primary500,
                  ),
                ),
              ),
            ),
        ],
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
          // 店家資訊卡
          if (_selectedMerchant != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _showDetail
                  ? _buildDetailCard(_selectedMerchant!)
                  : _buildInfoCard(_selectedMerchant!),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(SvMerchant merchant) {
    return FutureBuilder<bool>(
      future: _storageService.isLiked(merchant.id),
      builder: (context, snapshot) {
        final isLiked = snapshot.data ?? false;
        return Opacity(
          opacity: 0.8,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TPColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: TPColors.grayscale950.withOpacity(0.2),
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
                    // 愛心按鈕
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? TPColors.red500 : TPColors.grayscale400,
                      ),
                      onPressed: () => _toggleLike(merchant),
                    ),
                    // 叉叉按鈕
                    IconButton(
                      icon: const Icon(Icons.close, color: TPColors.grayscale950),
                      onPressed: _closeInfoCard,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (merchant.category != null) ...[
                  Text(
                    '類別：${merchant.category}',
                    style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
                  ),
                  const SizedBox(height: 8),
                ],
                InkWell(
                  onTap: () => _openGoogleMaps(merchant),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          merchant.address,
                          style: TPTextStyles.bodyRegular.copyWith(
                            color: TPColors.primary500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: TPColors.primary500),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '最低消費：${SvFormatter.formatCurrency(merchant.minSpend)}',
                  style: TPTextStyles.bodySemiBold.copyWith(color: TPColors.primary500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailCard(SvMerchant merchant) {
    return FutureBuilder<bool>(
      future: _storageService.isLiked(merchant.id),
      builder: (context, snapshot) {
        final isLiked = snapshot.data ?? false;
        return Opacity(
          opacity: 0.8,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TPColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: TPColors.grayscale950.withOpacity(0.2),
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
                        style: TPTextStyles.h2SemiBold.copyWith(color: TPColors.grayscale950),
                      ),
                    ),
                    // 愛心按鈕
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? TPColors.red500 : TPColors.grayscale400,
                      ),
                      onPressed: () => _toggleLike(merchant),
                    ),
                    // 叉叉按鈕
                    IconButton(
                      icon: const Icon(Icons.close, color: TPColors.grayscale950),
                      onPressed: _closeInfoCard,
                    ),
                  ],
                ),
                const Divider(),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (merchant.category != null) ...[
                          _buildDetailRow(
                            icon: Icons.category,
                            label: '類別',
                            value: merchant.category!,
                          ),
                          const SizedBox(height: 16),
                        ],
                        _buildDetailRow(
                          icon: Icons.location_on,
                          label: '地址',
                          value: merchant.address,
                          isClickable: true,
                          onTap: () => _openGoogleMaps(merchant),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          icon: Icons.payment,
                          label: '最低消費',
                          value: SvFormatter.formatCurrency(merchant.minSpend),
                        ),
                        if (merchant.phone != null) ...[
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            icon: Icons.phone,
                            label: '營業電話',
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
                        if (merchant.website != null) ...[
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            icon: Icons.language,
                            label: '官方網址',
                            value: merchant.website!,
                            isClickable: true,
                            onTap: () async {
                              final uri = Uri.parse(merchant.website!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        ],
                        if (merchant.description != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            '商家描述',
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
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isClickable = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: isClickable ? onTap : null,
      child: Row(
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: TPTextStyles.bodyRegular.copyWith(
                          color: isClickable ? TPColors.primary500 : TPColors.grayscale700,
                          decoration: isClickable ? TextDecoration.underline : null,
                        ),
                      ),
                    ),
                    if (isClickable)
                      const Icon(Icons.arrow_forward_ios, size: 12, color: TPColors.primary500),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
