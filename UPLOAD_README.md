# Firestore 資料上傳腳本使用說明

## 檔案位置
`upload_stores.js` - 位於專案根目錄

## 功能
從 CSV 檔案讀取店家資料並上傳到 Firestore 的 `stores` collection。

## 使用方法

### 基本用法（使用預設設定）
```bash
node upload_stores.js
```
預設會上傳 `scraper/vendors_formatted.csv` 的第 1-2 筆資料。

### 指定 CSV 檔案和行數範圍
```bash
node upload_stores.js <CSV檔案路徑> <開始行> <結束行>
```

### 範例
```bash
# 上傳 vendors_formatted.csv 的第 1-2 筆資料
node upload_stores.js scraper/vendors_formatted.csv 1 2

# 上傳第 1-10 筆資料
node upload_stores.js scraper/vendors_formatted.csv 1 10
```

## 資料欄位對應

| Firestore 欄位 | CSV 欄位 | 說明 |
|---------------|---------|------|
| `store_name` | 商家名稱 | 必填 |
| `address` | 地址 | 必填 |
| `phone` | 營業電話 | 可選，空值為 null |
| `businessHours` | 營業時間 | 可選，空值為 null |
| `website` | 網址 | 可選，空值為 null |
| `description` | 描述 | 可選，空值為 null |
| `category` | 類別 | 可選，空值為 null |
| `image_url` | - | 固定為 null（CSV 無此欄位） |
| `is_active` | - | 固定為 true |
| `location` | - | 固定為 [0° N, 0° E]（GeoPoint） |
| `updated_at` | - | 自動設為伺服器時間戳記 |

## 環境設定

### 本地測試（使用 Firestore Emulator）
1. 啟動 Firestore Emulator：
   ```bash
   firebase emulators:start --only firestore
   ```

2. 設定環境變數：
   ```bash
   export FIRESTORE_EMULATOR_HOST=localhost:8080
   export GCLOUD_PROJECT=dongzhi-taipei
   ```

3. 執行腳本：
   ```bash
   node upload_stores.js
   ```

### 生產環境
腳本會自動使用應用程式預設憑證（Application Default Credentials）。
確保已設定 Firebase 專案並完成認證：
```bash
firebase login
gcloud auth application-default login
```

## 注意事項

1. **行數計算**：行數從 1 開始計算（第 1 筆資料 = CSV 第 2 行，因為第 1 行是標題）
2. **必要欄位**：`store_name` 和 `address` 為必填，缺少任一欄位的資料會被跳過
3. **批次上傳**：使用 Firestore batch write，一次最多上傳 500 筆資料
4. **依賴套件**：腳本使用 `functions/node_modules` 中的套件，確保已執行 `cd functions && npm install`

## 錯誤處理

- 如果 CSV 檔案不存在，會顯示錯誤訊息
- 如果缺少必要欄位，該筆資料會被跳過並顯示警告
- 如果 Firebase 初始化失敗，會顯示錯誤並退出


