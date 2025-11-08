import 'package:geolocator/geolocator.dart';
import 'package:town_pass/module_sports_voucher/bean/sv_merchant.dart';
import 'package:town_pass/service/geo_locator_service.dart';

/// 動滋券定位服務
class SvLocationService {
  final GeoLocatorService _geoLocatorService;

  SvLocationService(this._geoLocatorService);

  /// 取得使用者當前位置
  Future<Position> getCurrentPosition() async {
    return await _geoLocatorService.position();
  }

  /// 計算兩點之間的距離（公里）
  double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  /// 計算使用者到店家的距離
  Future<double?> calculateDistanceToMerchant(
    Position userPosition,
    SvMerchant merchant,
  ) async {
    try {
      return calculateDistance(
        userPosition.latitude,
        userPosition.longitude,
        merchant.lat,
        merchant.lng,
      );
    } catch (e) {
      return null;
    }
  }

  /// 根據距離排序店家（由近到遠）
  Future<List<SvMerchant>> sortMerchantsByDistance(
    List<SvMerchant> merchants,
    Position userPosition,
  ) async {
    final List<MapEntry<SvMerchant, double>> merchantDistances = [];

    for (final merchant in merchants) {
      final distance = await calculateDistanceToMerchant(userPosition, merchant);
      if (distance != null) {
        merchantDistances.add(MapEntry(merchant, distance));
      }
    }

    merchantDistances.sort((a, b) => a.value.compareTo(b.value));

    return merchantDistances.map((entry) => entry.key).toList();
  }
}

