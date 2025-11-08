class SvProduct {
  final String id;
  final String productName;
  final String storeId;
  final String storeName;
  final double price;

  const SvProduct({
    required this.id,
    required this.productName,
    required this.storeId,
    required this.storeName,
    required this.price,
  });

  factory SvProduct.fromMap(Map<String, dynamic> map) {
    final id = map['id'] ?? map['product_id'];
    return SvProduct(
      id: id != null ? id.toString() : '',
      productName: (map['product_name'] ?? '').toString(),
      storeId: (map['store_id'] ?? '').toString(),
      storeName: (map['store_name'] ?? '').toString(),
      price: _parseDouble(map['price']),
    );
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
}

