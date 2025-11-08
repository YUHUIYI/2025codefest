import 'dart:math' as math;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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

  bool _distanceFilterEnabled = false;
  double _distanceThresholdKm = 5.0;
  bool _priceFilterEnabled = false;
  double _priceThreshold = 500.0;
  bool _likeFilterEnabled = false;

  Map<String, double> _storeMinProductPrices = {};
  Map<String, double> _storeDistancesKm = {};
  Set<String> _likedMerchantIds = {};
  String _filterMode = 'all'; // 'all', 'affordable', 'liked', 'distance', 'price', 'favorite'
  double _balance = 0;
  bool _showDetail = false;
  List<SvMerchant> _displayedMerchants = [];
  SvMerchant? _lastTappedMerchant;
  DateTime? _lastTapTime;
  Timer? _cameraUpdateTimer;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    final balanceArg = args?['balance'];
    if (balanceArg is num) {
      _priceThreshold = balanceArg.toDouble();
    }
    
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

  Map<String, double> _calculateMerchantDistances(
    List<SvMerchant> merchants,
    Position userPosition,
  ) {
    final Map<String, double> distances = {};
    for (final merchant in merchants) {
      if (merchant.lat == 0.0 && merchant.lng == 0.0) {
        continue;
      }
      distances[merchant.id] = _locationService.calculateDistance(
        userPosition.latitude,
        userPosition.longitude,
        merchant.lat,
        merchant.lng,
      );
    }
    return distances;
  }

  List<SvMerchant> _calculateFilteredMerchants() {
    return _allMerchants.where((merchant) {
      if (_distanceFilterEnabled && _userPosition != null) {
        final distance = _storeDistancesKm[merchant.id];
        if (distance == null || distance > _distanceThresholdKm) {
          return false;
        }
      }

      if (_priceFilterEnabled) {
        final minPrice = _storeMinProductPrices[merchant.id];
      if (minPrice == null || minPrice <= 0 || minPrice > _priceThreshold) {
          return false;
        }
      }

      if (_likeFilterEnabled) {
        if (!_likedMerchantIds.contains(merchant.id)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Set<Marker> _buildMarkers(List<SvMerchant> merchants) {
    return merchants
        .where((merchant) => merchant.lat != 0.0 && merchant.lng != 0.0)
        .map((merchant) {
      return Marker(
        markerId: MarkerId(merchant.id.toString()),
        position: LatLng(merchant.lat, merchant.lng),
        infoWindow: InfoWindow(
          title: merchant.name,
        ),
        onTap: () => _onMarkerTapped(merchant),
      );
    }).toSet();
  }

  void _applyFilters({VoidCallback? beforeSetState}) {
    setState(() {
      beforeSetState?.call();
      final filteredMerchants = _calculateFilteredMerchants();
      _displayedMerchants = filteredMerchants;
      _markers = _buildMarkers(filteredMerchants);
      if (_selectedMerchant != null &&
          !filteredMerchants.any((merchant) => merchant.id == _selectedMerchant!.id)) {
        _selectedMerchant = null;
      }
    });
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
      final minProductPrices = await _apiService.fetchStoreMinProductPrices();
      final likedIds = await _storageService.getLikes();
      final distances = _userPosition != null
          ? _calculateMerchantDistances(validMerchants, _userPosition!)
          : <String, double>{};

      if (mounted) {
        setState(() {
          _allMerchants = validMerchants;
          _storeMinProductPrices = minProductPrices;
          _likedMerchantIds = likedIds.toSet();
          _storeDistancesKm = distances;
        });
        _applyFilters();
        _logLikedMerchants('initial_load');
      }

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

  void _setDistanceFilterEnabled(bool enabled) {
    if (enabled && _userPosition == null) {
      SvDialogUtil.showErrorDialog(context, '尚未取得定位資訊，無法套用距離篩選');
      return;
    }

    final distances = (enabled && _userPosition != null)
        ? _calculateMerchantDistances(_allMerchants, _userPosition!)
        : _storeDistancesKm;
    double updatedThreshold = _distanceThresholdKm;
    if (enabled && _userPosition != null) {
      final computedMax =
          distances.isNotEmpty ? distances.values.reduce(math.max) : 0.0;
      final min = _distanceSliderMin;
      final fallbackMax = computedMax > min ? computedMax : min + 0.5;
      if (updatedThreshold <= 0 || updatedThreshold > fallbackMax) {
        updatedThreshold = fallbackMax;
      }
    }

    _applyFilters(beforeSetState: () {
      _distanceFilterEnabled = enabled;
      if (enabled && _userPosition != null) {
        _storeDistancesKm = distances;
        _distanceThresholdKm = updatedThreshold;
      }
    });
  }

  void _setPriceFilterEnabled(bool enabled) {
    if (enabled && _storeMinProductPrices.isEmpty) {
      SvDialogUtil.showErrorDialog(context, '尚未取得商品資料，無法套用金額篩選');
      return;
    }

    final sliderMax = _priceSliderMax;

    _applyFilters(beforeSetState: () {
      _priceFilterEnabled = enabled;
      if (enabled) {
        if (_priceThreshold <= 0 || _priceThreshold > sliderMax) {
          _priceThreshold = sliderMax;
        }
      }
    });
  }

  void _setLikeFilterEnabled(bool enabled) {
    _applyFilters(beforeSetState: () {
      _likeFilterEnabled = enabled;
    });
  }

  double get _distanceSliderMin => 0.5;

  double get _distanceSliderMax {
    if (_storeDistancesKm.isEmpty) {
      return 10.0;
    }
    final maxDistance = _storeDistancesKm.values.reduce(math.max);
    if (maxDistance > _distanceSliderMin) {
      return maxDistance;
    }
    return _distanceSliderMin + 0.5;
  }

  double get _priceSliderMin => 0.0;

  double get _priceSliderMax {
    if (_storeMinProductPrices.isEmpty) {
      return 1000.0;
    }
    final maxPrice = _storeMinProductPrices.values.reduce(math.max);
    return maxPrice > 0 ? maxPrice : 1000.0;
  }

  void _updateDistanceThreshold(double value) {
    final clamped = value.clamp(_distanceSliderMin, _distanceSliderMax).toDouble();
    _applyFilters(beforeSetState: () {
      _distanceThresholdKm = clamped;
    });
  }

  void _updatePriceThreshold(double value) {
    final clamped = value.clamp(_priceSliderMin, _priceSliderMax).toDouble();
    _applyFilters(beforeSetState: () {
      _priceThreshold = clamped;
    });
  }

  @override
  void dispose() {
    _cameraUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _logLikedMerchants(String source) {
    if (_likedMerchantIds.isEmpty) {
      debugPrint('[SV Map][$source] liked list is empty');
      return;
    }
    final preview = _likedMerchantIds.take(10).join(', ');
    debugPrint(
      '[SV Map][$source] liked merchants (${_likedMerchantIds.length} total): $preview'
          '${_likedMerchantIds.length > 10 ? ' ...' : ''}',
    );
  }

  void _onMarkerTapped(SvMerchant merchant) {
    final now = DateTime.now();
    final isDoubleTap = _lastTappedMerchant?.id == merchant.id &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 500;
    
    if (isDoubleTap) {
      // 雙擊：顯示詳細資料
      _showMerchantDetail(merchant);
      _lastTappedMerchant = null;
      _lastTapTime = null;
    } else {
      // 單擊：顯示簡易資訊卡
      setState(() {
        _selectedMerchant = merchant;
        _lastTappedMerchant = merchant;
        _lastTapTime = now;
      });
    }
  }

  Future<void> _updateDisplayedMerchants() async {
    List<SvMerchant> merchants = [];
    
    switch (_filterMode) {
      case 'affordable':
        merchants = _allMerchants.where((m) => m.isAffordable(_balance)).toList();
        break;
      case 'liked':
      case 'favorite':
        final likedIds = await _storageService.getLikes();
        merchants = _allMerchants.where((m) => likedIds.contains(m.id)).toList();
        break;
      case 'distance':
        if (_userPosition != null) {
          merchants = await _sortByDistance(_allMerchants);
        } else {
          merchants = _allMerchants;
        }
        break;
      case 'price':
        merchants = _sortByPrice(_allMerchants);
        break;
      default:
        merchants = _allMerchants;
    }
    
    setState(() {
      _displayedMerchants = merchants;
    });
  }

  Future<List<SvMerchant>> _sortByDistance(List<SvMerchant> merchants) async {
    if (_userPosition == null) return merchants;
    
    final List<MapEntry<SvMerchant, double>> merchantDistances = [];
    
    for (final merchant in merchants) {
      final distance = await _locationService.calculateDistanceToMerchant(
        _userPosition!,
        merchant,
      );
      if (distance != null) {
        merchantDistances.add(MapEntry(merchant, distance));
      }
    }
    
    merchantDistances.sort((a, b) => a.value.compareTo(b.value));
    return merchantDistances.map((entry) => entry.key).toList();
  }

  List<SvMerchant> _sortByPrice(List<SvMerchant> merchants) {
    final sorted = List<SvMerchant>.from(merchants);
    sorted.sort((a, b) => a.minSpend.compareTo(b.minSpend));
    return sorted;
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
        ),
        onTap: () => _onMarkerTapped(merchant),
      );
    }).toSet();
    
    setState(() {});
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        SvDialogUtil.showErrorDialog(context, '無法開啟 Google Maps');
      }
    }
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
                  FutureBuilder<bool>(
                    future: _storageService.isLiked(merchant.id),
                    builder: (context, snapshot) {
                      final isLiked = snapshot.data ?? false;
                      return IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.cancel_outlined,
                          color: isLiked ? TPColors.red500 : TPColors.grayscale400,
                        ),
                        onPressed: () {
                          _toggleLike(merchant);
                          Navigator.pop(context);
                          _showMerchantDetail(merchant);
                        },
                      );
                    },
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
                      isClickable: true,
                      onTap: () => _openGoogleMaps(merchant.lat, merchant.lng),
                    ),
                    const SizedBox(height: 16),
                    // 最低消費
                    _buildDetailRow(
                      icon: Icons.payment,
                      label: '最低消費',
                      value: SvFormatter.formatCurrency(merchant.minSpend),
                    ),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _toggleLike(SvMerchant merchant) async {
    final isLiked = _likedMerchantIds.contains(merchant.id);
    if (isLiked) {
      await _storageService.removeLike(merchant.id);
    } else {
      await _storageService.addLike(merchant.id);
    }

    _applyFilters(beforeSetState: () {
      if (isLiked) {
        _likedMerchantIds.remove(merchant.id);
      } else {
        _likedMerchantIds.add(merchant.id);
      }
    });
    _logLikedMerchants('toggle');

    if (_selectedMerchant != null &&
        !_displayedMerchants.any((m) => m.id == _selectedMerchant!.id)) {
      setState(() {
        _selectedMerchant = null;
      });
    }
  }

  Future<void> _openGoogleMapsForMerchant(SvMerchant merchant) async {
    await _openGoogleMaps(merchant.lat, merchant.lng);
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
          // 地圖
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userPosition != null
                  ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                  : const LatLng(25.0330, 121.5654), // 台北市預設位置
              zoom: 14.0,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            minMaxZoomPreference: const MinMaxZoomPreference(10.0, 18.0),
            zoomGesturesEnabled: true,
            zoomControlsEnabled: false,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: false,
            buildingsEnabled: false,
            indoorViewEnabled: false,
            trafficEnabled: false,
            mapToolbarEnabled: false,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: '距離',
                        selected: _distanceFilterEnabled,
                        onSelected: _setDistanceFilterEnabled,
                      ),
                      _buildFilterChip(
                        label: '金額',
                        selected: _priceFilterEnabled,
                        onSelected: _setPriceFilterEnabled,
                      ),
                      _buildFilterChip(
                        label: '收藏',
                        selected: _likeFilterEnabled,
                        onSelected: _setLikeFilterEnabled,
                      ),
                    ],
                  ),
                  if (_distanceFilterEnabled) ...[
                    const SizedBox(height: 12),
                    _buildFilterSlider(
                      label: '距離',
                      valueLabel: '${_distanceThresholdKm.toStringAsFixed(1)} 公里內',
                      value: _distanceThresholdKm,
                      min: _distanceSliderMin,
                      max: _distanceSliderMax,
                      onChanged: _updateDistanceThreshold,
                    ),
                  ],
                  if (_priceFilterEnabled) ...[
                    const SizedBox(height: 12),
                    _buildFilterSlider(
                      label: '金額上限',
                      valueLabel: '≤ ${SvFormatter.formatCurrency(_priceThreshold)}',
                      value: _priceThreshold,
                      min: _priceSliderMin,
                      max: _priceSliderMax,
                      onChanged: _updatePriceThreshold,
                    ),
                  ],
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
        // 取得該店家的最低商品價格，如果沒有則使用 merchant.minSpend
        final minPrice = _storeMinProductPrices[merchant.id] ?? merchant.minSpend;
        
        return Opacity(
          opacity: 0.95,
          child: InkWell(
            onTap: () {
              setState(() {
                _showDetail = true;
              });
            },
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
                    onTap: () => _openGoogleMapsForMerchant(merchant),
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
                  if (minPrice > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '最低消費：${SvFormatter.formatCurrency(minPrice)}',
                      style: TPTextStyles.bodySemiBold.copyWith(color: TPColors.primary500),
                    ),
                  ],
                ],
              ),
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
        // 取得該店家的最低商品價格，如果沒有則使用 merchant.minSpend
        final minPrice = _storeMinProductPrices[merchant.id] ?? merchant.minSpend;
        
        return Opacity(
          opacity: 0.95,
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
                          onTap: () => _openGoogleMapsForMerchant(merchant),
                        ),
                        if (minPrice > 0) ...[
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            icon: Icons.payment,
                            label: '最低消費',
                            value: SvFormatter.formatCurrency(minPrice),
                          ),
                        ],
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

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (selected) {
        onSelected(selected);
      },
      selectedColor: TPColors.primary500,
      labelStyle: TPTextStyles.bodyRegular.copyWith(
        color: selected ? TPColors.white : TPColors.grayscale700,
      ),
    );
  }

  Widget _buildFilterSlider({
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final clampedValue = value.clamp(min, max).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TPTextStyles.bodySemiBold.copyWith(color: TPColors.grayscale900),
            ),
            Text(
              valueLabel,
              style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
            ),
          ],
        ),
        Slider(
          value: clampedValue,
          min: min,
          max: max,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildMerchantCard(SvMerchant merchant) {
    final isLiked = _likedMerchantIds.contains(merchant.id);
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
                  isLiked ? Icons.favorite : Icons.cancel_outlined,
                  color: isLiked ? TPColors.red500 : TPColors.grayscale400,
                ),
                onPressed: () => _toggleLike(merchant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 類別
          if (merchant.category != null) ...[
            Text(
              '類別：${merchant.category}',
              style: TPTextStyles.bodyRegular.copyWith(color: TPColors.grayscale700),
            ),
            const SizedBox(height: 8),
          ],
          // 地址（可點擊）
          InkWell(
            onTap: () => _openGoogleMaps(merchant.lat, merchant.lng),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: TPColors.primary500,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    merchant.address,
                    style: TPTextStyles.bodyRegular.copyWith(
                      color: TPColors.primary500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 最低消費
          Text(
            '最低消費：${SvFormatter.formatCurrency(merchant.minSpend)}',
            style: TPTextStyles.bodySemiBold.copyWith(color: TPColors.primary500),
          ),
        ],
      ),
    );
  }
}
