# 環境變數設定說明

## 設定 Google Maps API Key

### 1. 複製環境變數範例檔案

```bash
cp .env.example .env
```

### 2. 編輯 .env 檔案

打開 `.env` 檔案，將 `YOUR_API_KEY_HERE` 替換為你的 Google Maps API Key：

```env
GOOGLE_MAPS_API_KEY=你的實際API_KEY
```

### 3. 取得 Google Maps API Key

1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 選擇或建立專案
3. 啟用以下 API：
   - Maps SDK for Android
   - Maps SDK for iOS
4. 前往「憑證」>「建立憑證」>「API 金鑰」
5. 複製 API Key 並貼到 `.env` 檔案中

### 4. Android 額外設定（可選）

如果你想要在建置時直接設定 API Key，可以在 `android/local.properties` 中加入：

```properties
GOOGLE_MAPS_API_KEY=你的實際API_KEY
```

### 5. 重新建置應用程式

設定完成後，重新建置應用程式：

```bash
flutter clean
flutter pub get
flutter run
```

## 注意事項

- `.env` 檔案已加入 `.gitignore`，不會被提交到 Git
- `.env.example` 是範例檔案，可以提交到 Git
- 請勿將實際的 API Key 提交到公開的儲存庫
- 建議在 Google Cloud Console 中設定 API Key 限制（限制為你的應用程式套件名稱）

