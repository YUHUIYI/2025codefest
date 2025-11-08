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
import 'package:town_pass/util/tp_text.dart';
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
  List<SvMerchant> _displayedMerchants = [];
  Set<Marker> _markers = {};
  SvMerchant? _selectedMerchant;

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
  
  // 用於追蹤點擊狀態（雙擊功能）
  SvMerchant? _lastTappedMerchant;
  DateTime? _lastTapTime;
  
  // 用於 debounce camera 更新
  Timer? _cameraUpdateTimer;
  bool _isCameraMoving = false;
  CameraPosition? _lastCameraPosition;
  DateTime? _lastUpdateTime;

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
    
    // 載入餘額
    _loadBalance();
    
    // 延遲到 widget 完全初始化後再載入資料
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
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
          snippet: '最低消費：${SvFormatter.formatCurrency(merchant.minSpend)}',
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

  void _onMarkerTapped(SvMerchant merchant) {
    setState(() {
      _selectedMerchant = merchant;
    });
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

  void _logLikedMerchants(String source) {
    if (_likedMerchantIds.isEmpty) {
      debugPrint('[SV Map][$source] liked list is empty');
      return;
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

  Future<void> _onFilterChanged(String mode) async {
    setState(() {
      _filterMode = mode;
      _selectedMerchant = null;
    });
    await _updateDisplayedMerchants();
    _updateMarkers();
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

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final content = Row(
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
                style: TPTextStyles.bodyRegular.copyWith(
                  color: onTap != null ? TPColors.primary500 : TPColors.grayscale700,
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }

  Future<void> _toggleLike(SvMerchant merchant) async {
    final isLiked = await _storageService.isLiked(merchant.id);
    if (isLiked) {
      await _storageService.removeLike(merchant.id);
    } else {
      await _storageService.addLike(merchant.id);
    }
    final preview = _likedMerchantIds.take(10).join(', ');
    debugPrint(
      '[SV Map][$source] liked merchants (${_likedMerchantIds.length} total): $preview'
          '${_likedMerchantIds.length > 10 ? ' ...' : ''}',
    );
  }

  /// Camera 移動時的回調（用於標記移動狀態）
  /// 不進行任何操作，只標記移動狀態，避免頻繁更新
  void _onCameraMove(CameraPosition position) {
    _isCameraMoving = true;
    _lastCameraPosition = position;
    
    // 取消之前的 timer，避免累積過多待處理的更新
    _cameraUpdateTimer?.cancel();
  }

  /// Camera 停止移動時的回調（只在這裡進行實際更新）
  /// 使用 debounce 和 throttle 機制來減少更新頻率，避免 buffer 過滿和頻繁調用 API
  void _onCameraIdle() {
    if (!_isCameraMoving) {
      return;
    }
    
    // 使用 throttle 機制：如果距離上次更新不到 1 秒，則忽略此次更新
    final now = DateTime.now();
    if (_lastUpdateTime != null && 
        now.difference(_lastUpdateTime!).inMilliseconds < 1000) {
      _isCameraMoving = false;
      return;
    }
    
    _isCameraMoving = false;
    
    // 使用 debounce 機制，延遲 800ms 後再處理
    // 增加延遲時間可以進一步減少更新頻率和 Google Maps API 調用
    _cameraUpdateTimer?.cancel();
    _cameraUpdateTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || _lastCameraPosition == null) {
        return;
      }
      
      // 更新最後更新時間
      _lastUpdateTime = DateTime.now();
      
      // 這裡可以根據需要更新可見區域的標記
      // 目前不需要額外操作，因為標記已經在初始載入時設定好了
      // 如果未來需要根據視圖範圍動態載入標記，可以在這裡實現
      // 但要注意：任何 API 調用都應該在這裡進行，並且要確保不會頻繁調用
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TPAppBar(
        title: '地圖查詢',
        backgroundColor: TPColors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (value) async {
              await _onFilterChanged(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'distance',
                child: Text('距離'),
              ),
              const PopupMenuItem(
                value: 'price',
                child: Text('價錢'),
              ),
              const PopupMenuItem(
                value: 'favorite',
                child: Text('收藏'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 剩餘金額顯示條
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: TPColors.primary50,
            child: Row(
              children: [
                Icon(
                  _balance > 0 ? Icons.account_balance_wallet : Icons.warning_amber_rounded,
                  size: 20,
                  color: _balance > 0 ? TPColors.primary500 : TPColors.grayscale600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _balance > 0
                        ? '💰 目前餘額：${SvFormatter.formatCurrency(_balance)}'
                        : '⚠️ 尚未儲存餘額，僅供瀏覽查詢。',
                    style: TPTextStyles.bodyRegular.copyWith(
                      color: _balance > 0 ? TPColors.primary600 : TPColors.grayscale600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 地圖區域
          Expanded(
            child: Stack(
              children: [
                Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent && _mapController != null) {
                      final delta = event.scrollDelta.dy;
                      if (delta < 0) {
                        // 向上滾動，放大
                        _mapController!.animateCamera(CameraUpdate.zoomIn());
                      } else if (delta > 0) {
                        // 向下滾動，縮小
                        _mapController!.animateCamera(CameraUpdate.zoomOut());
                      }
                    }
                  },
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _userPosition != null
                          ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                          : const LatLng(25.0330, 121.5654), // 台北市預設位置
                      zoom: 13,
                    ),
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    // 使用 onCameraIdle 而不是 onCameraMove 來減少更新頻率
                    // 只在 camera 停止移動時才觸發更新，避免頻繁調用 API
                    onCameraIdle: _onCameraIdle,
                    onCameraMove: _onCameraMove,
                    // 限制地圖的更新頻率，避免 buffer 過滿
                    mapType: MapType.normal,
                    // 限制縮放級別範圍，避免過度縮放導致頻繁請求地圖瓦片
                    minMaxZoomPreference: const MinMaxZoomPreference(10.0, 18.0),
                    // 啟用手勢控制
                    zoomGesturesEnabled: true,
                    zoomControlsEnabled: false, // 禁用縮放控制按鈕，減少 UI 更新
                    scrollGesturesEnabled: true,
                    tiltGesturesEnabled: false, // 禁用傾斜手勢，減少計算
                    rotateGesturesEnabled: false, // 禁用旋轉手勢，減少計算
                    // 禁用建築物和室內地圖，減少渲染負擔
                    buildingsEnabled: false,
                    indoorViewEnabled: false,
                    // 禁用交通和地形圖層，減少網路請求
                    trafficEnabled: false,
                    mapToolbarEnabled: false, // 禁用地圖工具欄
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
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
        ],
      ),
    );
  }
}

