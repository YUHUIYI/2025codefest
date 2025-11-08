# Firebase Cloud Functions - 動滋券店家 API

## 專案說明

這個 Firebase Cloud Functions 專案提供 RESTful API，供 Flutter 前端應用程式使用，用於查詢、篩選和管理動滋券店家資訊。

## 技術棧

- **Node.js**: 18
- **TypeScript**: 4.9+
- **Firebase Admin SDK**: 12.0+
- **Firebase Functions**: 4.5+
- **Express**: 4.18+
- **CORS**: 2.8+

## 專案結構

```
functions/
├── src/
│   ├── index.ts              # 主入口，匯出 Cloud Functions
│   ├── api/
│   │   ├── stores.ts         # 店家相關 API handlers
│   │   └── types.ts          # TypeScript 類型定義
│   └── utils/
│       ├── distance.ts       # 距離計算工具 (Haversine)
│       └── validation.ts     # 參數驗證工具
├── lib/                      # 編譯後的 JavaScript（自動生成）
├── package.json
├── tsconfig.json
└── README.md
```

## 安裝依賴

```bash
cd functions
npm install
```

## 本地開發

### 1. 編譯 TypeScript

```bash
npm run build
```

### 2. 使用 Firebase Emulators 測試

```bash
npm run serve
```

這會啟動 Firebase Emulators，API 將在 `http://localhost:5001` 上運行。

### 3. 測試 API

API 基礎 URL（本地）：
```
http://localhost:5001/<project-id>/asia-east1/api
```

## API 端點

### 1. GET /api/stores
取得所有有效店家列表

**回應範例：**
```json
{
  "success": true,
  "data": [
    {
      "id": "store123",
      "name": "YOUTH Fitness & Yoga",
      "address": "台北市內湖區瑞光路550號1樓",
      ...
    }
  ],
  "count": 10
}
```

### 2. GET /api/stores/:id
取得單一店家詳情

**路徑參數：**
- `id`: 店家 document ID

### 3. GET /api/stores/filter
依條件篩選店家

**查詢參數：**
- `category` (string, optional): 類別篩選
- `usable_item` (string, optional): 可使用項目篩選
- `minPrice` (number, optional): 最低價格
- `maxPrice` (number, optional): 最高價格
- `lat` (number, optional): 使用者緯度
- `lng` (number, optional): 使用者經度
- `radius` (number, optional): 搜尋半徑（公里），預設 10
- `liked` (boolean, optional): 只顯示收藏的店家
- `userId` (string, optional): 使用者 ID（用於 liked 篩選）

**範例：**
```
GET /api/stores/filter?category=運動用品店&maxPrice=500&lat=25.083&lng=121.564&radius=5
```

### 4. POST /api/stores/:id/like
切換店家收藏狀態

**路徑參數：**
- `id`: 店家 document ID

**請求體：**
```json
{
  "userId": "user123"
}
```

**回應範例：**
```json
{
  "success": true,
  "liked": true,
  "message": "Added to favorites"
}
```

### 5. GET /api/health
健康檢查端點

## 部署

### 1. 設定 Firebase 專案

編輯 `.firebaserc`，將 `your-project-id` 替換為你的 Firebase 專案 ID：

```json
{
  "projects": {
    "default": "your-actual-project-id"
  }
}
```

### 2. 登入 Firebase

```bash
firebase login
```

### 3. 部署 Functions

```bash
cd functions
npm run deploy
```

或從專案根目錄：

```bash
firebase deploy --only functions
```

### 4. 取得 API URL

部署完成後，Firebase 會提供 API URL，格式如下：
```
https://asia-east1-<project-id>.cloudfunctions.net/api
```

## 資料結構

### Store 介面

```typescript
interface Store {
  id?: string;
  name: string;
  address: string;
  phone: string;
  businessHours: string;
  website: string;
  description: string;
  category: string;
  usable_items: string[];
  sample_products: Product[];
  price_range: { min: number; max: number };
  location: GeoPoint;
  image_url: string;
  is_active: boolean;
  updated_at: Timestamp;
  likedBy?: string[];
  distance?: number;  // 計算後的距離（公里）
}
```

### Product 介面

```typescript
interface Product {
  name: string;
  price: number;
  category: string;
  note?: string;
}
```

## 注意事項

1. **Firestore 規則**：目前設定為只允許讀取有效店家，寫入需透過 Admin SDK（後端）
2. **CORS**：目前允許所有來源，生產環境建議限制特定網域
3. **距離計算**：使用 Haversine formula，計算兩點間的大圓距離
4. **價格篩選**：由於 Firestore 限制，價格篩選在記憶體中處理

## 疑難排解

### 編譯錯誤
確保已安裝所有依賴：
```bash
npm install
```

### 部署失敗
檢查 Firebase 登入狀態：
```bash
firebase login:list
```

### API 無法存取
確認 Firestore 規則已正確設定，且 `is_active` 欄位為 `true`。

