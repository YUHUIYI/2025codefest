# 修復 Google Maps 授權失敗問題

## 🔴 當前問題

從日誌中看到：
```
E/Google Android Maps SDK: Authorization failure.
E/Google Android Maps SDK: Ensure that the "Maps SDK for Android" is enabled.
E/Google Android Maps SDK: Ensure that the following Android Key exists:
E/Google Android Maps SDK:       API Key: AIzaSyAzE3jH8MTGlUMADfirY_Of82Za-gJWuuw
E/Google Android Maps SDK:       Android Application (<cert_fingerprint>;<package_name>): 
E/Google Android Maps SDK:       3D:0F:DA:FC:76:0D:3E:F3:80:71:93:76:2C:A1:CC:C8:0E:80:78:04;com.example.townpass
```

**問題診斷**：
- ✅ API Key 已正確配置在 `android/local.properties`
- ❌ Google Cloud Console 中的 API Key 配置不正確

## 🔧 解決步驟

### 步驟 1：檢查 Google Cloud Console 配置

1. **前往 [Google Cloud Console](https://console.cloud.google.com/)**

2. **選擇你的專案**（或建立新專案）

3. **啟用 Maps SDK for Android**：
   - 前往 [API 和服務 > 程式庫](https://console.cloud.google.com/apis/library)
   - 搜尋 "Maps SDK for Android"
   - 點擊進入並**啟用**（如果尚未啟用）

4. **檢查 API Key 設定**：
   - 前往 [API 和服務 > 憑證](https://console.cloud.google.com/apis/credentials)
   - 找到你的 API Key：`AIzaSyAzE3jH8MTGlUMADfirY_Of82Za-gJWuuw`
   - 點擊編輯

### 步驟 2：設定 API Key 限制

在 API Key 編輯頁面：

#### A. 應用程式限制

選擇 **Android 應用程式**，然後添加：

1. **套件名稱**：
   ```
   com.example.townpass
   ```

2. **SHA-1 憑證指紋**：
   ```
   3D:0F:DA:FC:76:0D:3E:F3:80:71:93:76:2C:A1:CC:C8:0E:80:78:04
   ```

   **如何取得 SHA-1 指紋**：
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
   然後複製 "SHA1:" 後面的值（去掉冒號，轉換為大寫）

#### B. API 限制

選擇 **限制金鑰**，然後勾選：
- ✅ **Maps SDK for Android**

**重要**：不要選擇其他 API，只選擇 Maps SDK for Android

### 步驟 3：儲存並等待生效

1. 點擊 **儲存**
2. **等待 1-5 分鐘**讓設定生效
3. 重新運行應用

### 步驟 4：驗證配置

運行應用後，檢查日誌：

✅ **成功標誌**：
- 沒有 `Authorization failure` 錯誤
- 地圖正常顯示

❌ **如果仍然失敗**：
1. 確認已啟用 "Maps SDK for Android"
2. 確認 SHA-1 指紋完全匹配（包括大小寫）
3. 確認套件名稱完全匹配：`com.example.townpass`
4. 確認 API Key 限制只選擇了 "Maps SDK for Android"

## 📋 檢查清單

- [ ] 已在 Google Cloud Console 啟用 "Maps SDK for Android"
- [ ] API Key 已設定應用程式限制為 "Android 應用程式"
- [ ] 已添加套件名稱：`com.example.townpass`
- [ ] 已添加 SHA-1 指紋：`3D:0F:DA:FC:76:0D:3E:F3:80:71:93:76:2C:A1:CC:C8:0E:80:78:04`
- [ ] API 限制只選擇了 "Maps SDK for Android"
- [ ] 已儲存設定並等待 1-5 分鐘
- [ ] 已重新運行應用

## 🔍 常見問題

### Q: SHA-1 指紋不匹配怎麼辦？

**A**: 確保：
1. 使用正確的 keystore（debug 模式使用 `~/.android/debug.keystore`）
2. SHA-1 指紋格式正確（20 個十六進制字符，用冒號分隔）
3. 在 Google Cloud Console 中輸入時，格式為：`XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX`

### Q: 套件名稱不匹配怎麼辦？

**A**: 檢查 `android/app/build.gradle` 中的 `applicationId`：
```gradle
applicationId "com.example.townpass"
```

### Q: 已經設定正確但還是失敗？

**A**: 
1. 等待更長時間（最多 10 分鐘）
2. 清除應用資料並重新安裝
3. 檢查 Google Cloud Console 中的 API 使用量是否有限制
4. 確認帳單已啟用（Google Maps 需要啟用帳單）

## 📝 相關資源

- [Google Maps Android SDK 設定指南](https://developers.google.com/maps/documentation/android-sdk/start)
- [取得 API Key](https://developers.google.com/maps/documentation/android-sdk/get-api-key)
- [API Key 最佳實踐](https://developers.google.com/maps/api-security-best-practices)

