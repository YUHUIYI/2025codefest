import 'package:cloud_firestore/cloud_firestore.dart';

/// 動滋券合作店家資料模型
class SvMerchant {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final double minSpend;
  final String? phone;
  final String? description;
  final String? imageUrl;
  final String? category;
  final String? businessHours;
  final String? website;
  final bool isActive;
  final DateTime? updatedAt;

  const SvMerchant({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.minSpend,
    this.phone,
    this.description,
    this.imageUrl,
    this.category,
    this.businessHours,
    this.website,
    this.isActive = true,
    this.updatedAt,
  });

  /// 由 Firestore 或本地 JSON 的 Map 建立 [SvMerchant]
  factory SvMerchant.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    final position = _parseLocation(map);
    return SvMerchant(
      id: _parseNullableString(map['id']) ??
          _parseNullableString(documentId) ??
          '',
      name: (map['store_name'] ?? map['name'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      lat: position['lat'] ?? _parseDouble(map['lat']),
      lng: position['lng'] ?? _parseDouble(map['lng']),
      minSpend: _parseDouble(map['min_spend'] ?? map['minSpend']),
      phone: _parseNullableString(map['phone']),
      description: _parseNullableString(map['description']),
      imageUrl: _parseNullableString(map['image_url'] ?? map['imageUrl']),
      category: _parseNullableString(map['category']),
      businessHours: _parseNullableString(
        map['businessHours'] ?? map['business_hours'],
      ),
      website: _parseNullableString(map['website']),
      isActive: _parseBool(map['is_active']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  factory SvMerchant.fromJson(Map<String, dynamic> json) =>
      SvMerchant.fromMap(json);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'min_spend': minSpend,
      'phone': phone,
      'description': description,
      'image_url': imageUrl,
      'category': category,
      'businessHours': businessHours,
      'website': website,
      'is_active': isActive,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// 檢查餘額是否足夠消費
  bool isAffordable(double balance) {
    return balance >= minSpend;
  }

  static Map<String, double> _parseLocation(Map<String, dynamic> map) {
    final location = map['location'];
    if (location is GeoPoint) {
      return {
        'lat': location.latitude,
        'lng': location.longitude,
      };
    }
    if (location is Map) {
      final lat = location['lat'] ?? location['latitude'];
      final lng = location['lng'] ?? location['longitude'];
      return {
        'lat': _parseDouble(lat),
        'lng': _parseDouble(lng),
      };
    }
    if (location is List && location.length >= 2) {
      return {
        'lat': _parseDouble(location[0]),
        'lng': _parseDouble(location[1]),
      };
    }
    if (location is String) {
      final matches =
          RegExp(r'(-?\d+(?:\.\d+)?)').allMatches(location).toList();
      if (matches.length >= 2) {
        final lat = double.tryParse(matches[0].group(0)!);
        final lng = double.tryParse(matches[1].group(0)!);
        if (lat != null && lng != null) {
          return {
            'lat': lat,
            'lng': lng,
          };
        }
      }
    }
    return const <String, double>{};
  }

  static double _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return true;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) {
      return null;
    }
    return value.toString();
  }
}
