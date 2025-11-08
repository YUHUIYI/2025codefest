# 修復 Google Map 空白問題

## 🔴 問題診斷

從日誌中發現以下錯誤：

1. **API Key 為空**（第444行）：
   ```
   E/Google Android Maps SDK: API Key: 
   ```

2. **Method Channel 未實現**（第36行）：
   ```
   MissingPluginException(No implementation found for method setApiKey
   ```

3. **授權失敗**（第327-332行）：
   ```
   E/Google Android Maps SDK: Authorization failure
   ```

## ✅ 已修復的問題

1. ✅ **已添加 Android Method Channel 實現**
   - 修改了 `android/app/src/main/kotlin/com/example/townpass/MainActivity.kt`
   - 現在可以正確處理 `setApiKey` 方法調用

## 🔧 需要你完成的配置

### 步驟 1：取得 Google Maps API Key

1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 選擇或建立專案
3. 啟用 **Maps SDK for Android**
4. 建立 API Key
5. 設定 API Key 限制：
   - **應用程式限制**：Android 應用程式
   - **套件名稱**：`com.example.townpass`
   - **SHA-1 憑證指紋**：`3D:0F:DA:FC:76:0D:3E:F3:80:71:93:76:2C:A1:CC:C8:0E:80:78:04`
   - **API 限制**：僅允許 Maps SDK for Android

### 步驟 2：配置 API Key

**方法 A：使用 local.properties（推薦，用於 Android）**

編輯 `android/local.properties`，添加：

```properties
GOOGLE_MAPS_API_KEY=你的_API_Key_在這裡
```

**方法 B：使用 .env 文件（用於 Flutter 層）**

1. 複製 `env.example` 為 `.env`：
   ```bash
   cp env.example .env
   ```

2. 編輯 `.env`，將 `YOUR_API_KEY_HERE` 替換為你的實際 API Key：
   ```env
   GOOGLE_MAPS_API_KEY=你的_API_Key_在這裡
   ```

**建議：兩種方法都配置，確保萬無一失！**

### 步驟 3：重新編譯應用

```bash
# 清理建置快取
flutter clean

# 取得依賴
flutter pub get

# 重新編譯並運行
flutter run
```

## 📋 檢查清單

- [ ] 已在 Google Cloud Console 建立 API Key
- [ ] 已啟用 Maps SDK for Android
- [ ] 已在 `android/local.properties` 添加 `GOOGLE_MAPS_API_KEY`
- [ ] 已建立 `.env` 文件並配置 API Key（可選但建議）
- [ ] 已執行 `flutter clean` 和 `flutter pub get`
- [ ] 已重新運行應用

## 🔍 驗證配置

運行應用後，檢查日誌：

✅ **成功標誌**：
- 沒有 `Authorization failure` 錯誤
- 沒有 `MissingPluginException` 錯誤
- 地圖正常顯示

❌ **如果仍然空白**：
1. 確認 API Key 已正確配置
2. 確認已啟用 Maps SDK for Android
3. 確認 SHA-1 憑證指紋正確
4. 檢查 Google Cloud Console 中的 API 使用量是否有限制

## 📝 相關文件

- `GOOGLE_MAPS_SETUP.md` - 完整的 Google Maps 設定指南
- `android/app/src/main/AndroidManifest.xml` - Android 配置
- `lib/config/google_maps_config.dart` - Flutter 配置類別

