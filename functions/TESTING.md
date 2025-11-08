# 測試指南

## 本地測試步驟

### 1. 安裝依賴

```bash
cd functions
npm install
```

### 2. 編譯 TypeScript

```bash
npm run build
```

### 3. 啟動 Firebase Emulators

```bash
npm run serve
```

或從專案根目錄：

```bash
firebase emulators:start --only functions,firestore
```

### 4. 測試 API

API 基礎 URL（本地）：
```
http://localhost:5001/<project-id>/asia-east1/api
```

**注意**：`<project-id>` 需要替換為你的 Firebase 專案 ID。

## API 測試範例

### 1. 健康檢查

```bash
curl http://localhost:5001/<project-id>/asia-east1/api/health
```

### 2. 取得所有店家

```bash
curl http://localhost:5001/<project-id>/asia-east1/api/stores
```

### 3. 取得單一店家

```bash
curl http://localhost:5001/<project-id>/asia-east1/api/stores/<store-id>
```

### 4. 篩選店家

```bash
# 依類別篩選
curl "http://localhost:5001/<project-id>/asia-east1/api/stores/filter?category=運動用品店"

# 依價格篩選
curl "http://localhost:5001/<project-id>/asia-east1/api/stores/filter?maxPrice=500"

# 依距離篩選
curl "http://localhost:5001/<project-id>/asia-east1/api/stores/filter?lat=25.083&lng=121.564&radius=5"

# 組合篩選
curl "http://localhost:5001/<project-id>/asia-east1/api/stores/filter?category=運動用品店&maxPrice=500&lat=25.083&lng=121.564&radius=5"
```

### 5. 切換收藏狀態

```bash
curl -X POST http://localhost:5001/<project-id>/asia-east1/api/stores/<store-id>/like \
  -H "Content-Type: application/json" \
  -d '{"userId": "user123"}'
```

## 使用 Postman 測試

1. 匯入以下集合設定：

```json
{
  "info": {
    "name": "動滋券店家 API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Health Check",
      "request": {
        "method": "GET",
        "url": "http://localhost:5001/<project-id>/asia-east1/api/health"
      }
    },
    {
      "name": "Get All Stores",
      "request": {
        "method": "GET",
        "url": "http://localhost:5001/<project-id>/asia-east1/api/stores"
      }
    },
    {
      "name": "Filter Stores",
      "request": {
        "method": "GET",
        "url": {
          "raw": "http://localhost:5001/<project-id>/asia-east1/api/stores/filter?category=運動用品店&maxPrice=500",
          "host": ["localhost:5001"],
          "path": ["<project-id>", "asia-east1", "api", "stores", "filter"],
          "query": [
            {"key": "category", "value": "運動用品店"},
            {"key": "maxPrice", "value": "500"}
          ]
        }
      }
    }
  ]
}
```

## 測試資料準備

在 Firestore Emulator 中建立測試資料：

1. 啟動 Emulator 後，前往 Firebase Console Emulator UI：
   ```
   http://localhost:4000
   ```

2. 在 Firestore 中建立 `stores` 集合

3. 新增測試店家文件，範例：

```json
{
  "name": "測試店家",
  "address": "台北市信義區松高路11號",
  "phone": "02-1234-5678",
  "businessHours": "10:00-22:00",
  "website": "https://example.com",
  "description": "測試店家描述",
  "category": "運動用品店",
  "usable_items": ["運動服飾", "運動鞋"],
  "sample_products": [
    {
      "name": "運動襪",
      "price": 100,
      "category": "運動服飾",
      "note": "透氣棉質"
    }
  ],
  "price_range": {
    "min": 100,
    "max": 800
  },
  "location": {
    "latitude": 25.083,
    "longitude": 121.564
  },
  "image_url": "https://example.com/image.jpg",
  "is_active": true,
  "updated_at": "2025-01-01T00:00:00Z",
  "likedBy": []
}
```

## 常見問題

### Q: Emulator 無法啟動
A: 確保已安裝 Firebase CLI：
```bash
npm install -g firebase-tools
```

### Q: 編譯錯誤
A: 檢查 TypeScript 版本和依賴：
```bash
npm install
npm run build
```

### Q: API 回傳 404
A: 確認：
1. Emulator 已啟動
2. URL 中的專案 ID 正確
3. 路由路徑正確（包含 `/api` 前綴）

### Q: Firestore 查詢失敗
A: 確認：
1. Firestore Emulator 已啟動
2. 測試資料已建立
3. `is_active` 欄位為 `true`

