import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:town_pass/module_sports_voucher/bean/sv_merchant.dart';

/// 動滋券 API 服務
/// 目前使用模擬資料，未來可替換為真實 API
class SvApiService {
  static const String _mockDataPath = 'assets/mock_data/sv_merchants.json';

  /// 取得所有合作店家
  Future<List<SvMerchant>> fetchMerchants() async {
    try {
      // 模擬 API 延遲
      await Future.delayed(const Duration(milliseconds: 500));

      // 從本地 JSON 檔案讀取模擬資料
      final String jsonString = await rootBundle.loadString(_mockDataPath);
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      
      return jsonList.map((json) => SvMerchant.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      // 如果讀取失敗，返回預設模擬資料
      return _getDefaultMockData();
    }
  }

  /// 根據餘額取得可用店家
  Future<List<SvMerchant>> fetchAffordableMerchants(double balance) async {
    final allMerchants = await fetchMerchants();
    return allMerchants.where((merchant) => merchant.isAffordable(balance)).toList();
  }

  /// 根據 ID 取得店家
  Future<SvMerchant?> fetchMerchantById(int id) async {
    final allMerchants = await fetchMerchants();
    try {
      return allMerchants.firstWhere((merchant) => merchant.id == id);
    } catch (e) {
      return null;
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
      ),
    ];
  }
}

