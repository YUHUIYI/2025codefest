import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:town_pass/module_sports_voucher/bean/sv_merchant.dart';

/// 動滋券 API 服務
/// 先嘗試讀取 Firebase Firestore，若失敗再回退至本地假資料
class SvApiService {
  SvApiService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _mockDataPath = 'assets/mock_data/sv_merchants.json';
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _storeCollection =>
      _firestore.collection('stores');

  /// 取得所有合作店家
  Future<List<SvMerchant>> fetchMerchants() async {
    try {
      final snapshot =
          await _storeCollection.where('is_active', isEqualTo: true).get();

      if (snapshot.docs.isEmpty) {
        return await _loadMockData();
      }

      return snapshot.docs
          .map(
            (doc) => SvMerchant.fromMap(
              doc.data(),
              documentId: doc.id,
            ),
          )
          .toList();
    } catch (_) {
      return await _loadMockData();
    }
  }

  /// 根據餘額取得可用店家
  Future<List<SvMerchant>> fetchAffordableMerchants(double balance) async {
    final merchants = await fetchMerchants();
    return merchants.where((merchant) => merchant.isAffordable(balance)).toList();
  }

  /// 根據 ID 取得店家（優先查 Firestore，失敗後回退至本地資料）
  Future<SvMerchant?> fetchMerchantById(int id) async {
    try {
      final snapshot =
          await _storeCollection.where('id', isEqualTo: id).limit(1).get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return SvMerchant.fromMap(doc.data(), documentId: doc.id);
      }
    } catch (_) {
      // ignore and fallback to local data
    }

    final fallback = await _loadMockData();
    try {
      return fallback.firstWhere((merchant) => merchant.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<SvMerchant>> _loadMockData() async {
    try {
      final jsonString = await rootBundle.loadString(_mockDataPath);
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map(
            (json) => SvMerchant.fromMap(json as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return _getDefaultMockData();
    }
  }

  /// 預設模擬資料（當 JSON 檔案不存在時使用）
  List<SvMerchant> _getDefaultMockData() {
    return [
      SvMerchant(
        id: 1,
        name: '台北運動中心',
        address: '台北市信義區信義路五段1號',
        lat: 25.0330,
        lng: 121.5654,
        minSpend: 100.0,
        phone: '02-2345-6789',
        description: '提供多種運動設施與課程',
        category: '運動中心',
        businessHours: '每日 08:00-22:00',
        website: null,
        isActive: true,
      ),
      SvMerchant(
        id: 2,
        name: '陽光健身房',
        address: '台北市大安區忠孝東路四段200號',
        lat: 25.0414,
        lng: 121.5533,
        minSpend: 200.0,
        phone: '02-2777-8888',
        description: '24小時營業的現代化健身房',
        category: '健身房',
        businessHours: '24 小時營業',
        website: null,
        isActive: true,
      ),
      SvMerchant(
        id: 3,
        name: '游泳俱樂部',
        address: '台北市中山區南京東路三段100號',
        lat: 25.0520,
        lng: 121.5440,
        minSpend: 150.0,
        phone: '02-2500-1234',
        description: '專業游泳教學與訓練',
        category: '游泳',
        businessHours: '每日 09:00-21:00',
        website: null,
        isActive: true,
      ),
      SvMerchant(
        id: 4,
        name: '羽球館',
        address: '台北市松山區八德路四段200號',
        lat: 25.0480,
        lng: 121.5570,
        minSpend: 300.0,
        phone: '02-2766-7890',
        description: '專業羽球場地租借',
        category: '羽球',
        businessHours: '每日 09:00-23:00',
        website: null,
        isActive: true,
      ),
      SvMerchant(
        id: 5,
        name: '網球場',
        address: '台北市內湖區內湖路一段200號',
        lat: 25.0790,
        lng: 121.5650,
        minSpend: 250.0,
        phone: '02-2799-5678',
        description: '戶外網球場地',
        category: '網球',
        businessHours: '每日 08:00-22:00',
        website: null,
        isActive: true,
      ),
    ];
  }
}

