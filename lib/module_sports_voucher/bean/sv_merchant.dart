import 'package:json_annotation/json_annotation.dart';

part 'sv_merchant.g.dart';

/// 動滋券合作店家資料模型
@JsonSerializable()
class SvMerchant {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  @JsonKey(name: 'min_spend')
  final double minSpend;
  final String? phone;
  final String? description;
  final String? imageUrl;

  SvMerchant({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.minSpend,
    this.phone,
    this.description,
    this.imageUrl,
  });

  factory SvMerchant.fromJson(Map<String, dynamic> json) => _$SvMerchantFromJson(json);

  Map<String, dynamic> toJson() => _$SvMerchantToJson(this);

  /// 檢查餘額是否足夠消費
  bool isAffordable(double balance) {
    return balance >= minSpend;
  }
}

