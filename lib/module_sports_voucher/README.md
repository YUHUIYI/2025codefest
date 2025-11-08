# 台北市動滋券配對與查詢系統

## 模組說明

本模組為嵌入於台北通（TaipeiPASS）App 的前端模組，提供使用者依據「動滋券剩餘金額」進行合作店家查詢與互動配對的功能。

## 功能特色

- 🏠 **首頁**：輸入剩餘金額、前往動滋券官方網站、導向查詢功能
- 🗺️ **地圖查詢**：顯示合作店家位置、支援 GPS 定位與金額篩選
- 🔍 **文字搜尋**：商家清單檢索與 Like 列表管理
- 💝 **配對頁**：Tinder 式互動滑動介面，根據剩餘金額推薦店家

## 使用方式

### 在主程式中載入模組

```dart
import 'package:town_pass/module_sports_voucher/sv_module_entry.dart';

// 方式 1: 作為獨立應用程式
runApp(SportsVoucherModule(initialBalance: 500.0));

// 方式 2: 透過路由導航
Get.toNamed('/sv/home', arguments: {'initialBalance': 500.0});
```

### 模組路由

- `/sv/home` - 首頁
- `/sv/map` - 地圖查詢頁
- `/sv/search` - 文字搜尋頁
- `/sv/match` - 配對頁

## 資料結構

### SvMerchant（店家資料模型）

```dart
class SvMerchant {
  final int id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final double minSpend;
  final String? phone;
  final String? description;
  final String? imageUrl;
}
```

## 服務層

- **SvApiService**: 管理 API 請求（目前使用模擬資料）
- **SvLocationService**: 處理 GPS 定位與距離計算
- **SvStorageService**: 管理 Like 清單本地儲存

## 注意事項

1. 地圖功能需要 Google Maps API Key（需在 AndroidManifest.xml 和 Info.plist 中配置）
2. 定位功能需要位置權限
3. 模擬資料位於 `assets/mock_data/sv_merchants.json`

## 命名規範

所有檔案、class、route 均使用 `Sv` 前綴，避免與主程式命名衝突。

