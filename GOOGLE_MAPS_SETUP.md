# Google Maps 串接設定指南

## 概述

本專案已整合 Google Maps Flutter 套件，需要配置 Google Maps API Key 才能正常使用地圖功能。

## 已完成的配置

✅ **套件安裝**：`google_maps_flutter: ^2.5.0` 已加入 `pubspec.yaml`  
✅ **Android 配置**：已在 `android/app/src/main/AndroidManifest.xml` 中添加 API Key 配置位置  
✅ **iOS 配置**：已在 `ios/Runner/Info.plist` 中添加 API Key 配置位置  
✅ **地圖頁面**：已實作 `lib/module_sports_voucher/page/sv_map_page.dart`

## 需要完成的步驟

### 1. 取得 Google Maps API Key

1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 建立新專案或選擇現有專案
3. 啟用以下 API：
   - **Maps SDK for Android**（Android 使用）
   - **Maps SDK for iOS**（iOS 使用）
4. 建立憑證（Credentials）：
   - **Android**：需要 SHA-1 憑證指紋（可在 `android/app` 目錄下執行 `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`）
   - **iOS**：使用 Bundle ID（可在 Xcode 專案設定中查看）
5. 建立 API Key 並複製

### 2. 配置 Android API Key

編輯 `android/app/src/main/AndroidManifest.xml`，將 `YOUR_GOOGLE_MAPS_API_KEY_HERE` 替換為您的實際 API Key：

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="您的_Android_API_Key" />
```

### 3. 配置 iOS API Key

編輯 `ios/Runner/Info.plist`，將 `YOUR_GOOGLE_MAPS_API_KEY_HERE` 替換為您的實際 API Key：

```xml
<key>GMSApiKey</key>
<string>您的_iOS_API_Key</string>
```

**注意**：Android 和 iOS 可以使用不同的 API Key，建議分別建立並設定限制。

### 4. 設定 API Key 限制（建議）

為了安全性，建議在 Google Cloud Console 中為 API Key 設定限制：

- **應用程式限制**：
  - Android：限制為您的應用程式套件名稱（`com.example.townpass`）
  - iOS：限制為您的 Bundle ID
- **API 限制**：僅允許 Maps SDK for Android/iOS

### 5. 測試地圖功能

配置完成後，執行以下步驟測試：

```bash
# 清理建置快取
flutter clean

# 取得依賴
flutter pub get

# 執行應用程式
flutter run
```

導航至地圖頁面（`/sv/map`）確認地圖是否正常顯示。

## 現有地圖功能

專案中已實作的地圖功能位於 `lib/module_sports_voucher/page/sv_map_page.dart`，包含：

- 🗺️ 地圖顯示與標記
- 📍 GPS 定位
- 🔍 店家篩選（全部/可用/收藏）
- 💝 店家資訊卡片
- ⭐ 收藏功能

## 疑難排解

### 地圖顯示為空白

1. 確認 API Key 已正確配置
2. 確認已啟用對應平台的 Maps SDK
3. 檢查 API Key 限制設定是否正確
4. 查看 Logcat（Android）或 Console（iOS）是否有錯誤訊息

### Android 地圖無法顯示

- 確認 `AndroidManifest.xml` 中的 API Key 配置正確
- 確認已啟用 **Maps SDK for Android**
- 檢查 SHA-1 憑證指紋是否正確設定

### iOS 地圖無法顯示

- 確認 `Info.plist` 中的 API Key 配置正確
- 確認已啟用 **Maps SDK for iOS**
- 檢查 Bundle ID 是否正確設定

## 相關資源

- [Google Maps Flutter 官方文件](https://pub.dev/packages/google_maps_flutter)
- [Google Maps Platform 文件](https://developers.google.com/maps/documentation)
- [取得 API Key 指南](https://developers.google.com/maps/documentation/android-sdk/get-api-key)

