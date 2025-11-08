import * as admin from 'firebase-admin';

/**
 * Firestore GeoPoint 類型
 */
export type GeoPoint = admin.firestore.GeoPoint;

/**
 * Firestore Timestamp 類型
 */
export type Timestamp = admin.firestore.Timestamp;

/**
 * 商品介面
 */
export interface Product {
  name: string;                    // 商品名稱
  price: number;                   // 單品大致價格
  category: string;                // 商品類型
  note?: string;                   // 可選擇性備註
}

/**
 * 店家介面（對應 Firestore stores 集合）
 */
export interface Store {
  id?: string;                     // Document ID（從 Firestore 取得）
  name: string;                    // 店家名稱
  address: string;                 // 地址
  phone: string;                   // 營業電話
  businessHours: string;           // 營業時間
  website: string;                 // 網址
  description: string;             // 描述
  category: string;                // 類別
  usable_items: string[];          // 可使用動滋券的大項
  sample_products: Product[];      // 代表性商品清單
  price_range: {                   // 價格區間
    min: number;
    max: number;
  };
  location: GeoPoint;              // 地理位置 (Firestore GeoPoint)
  image_url: string;               // 店家封面圖
  is_active: boolean;              // 是否有效店家
  updated_at: Timestamp;           // 最後更新時間
  likedBy?: string[];              // 收藏的使用者 ID 列表
  distance?: number;               // 距離（公里，用於篩選時計算）
}

/**
 * 篩選參數介面
 */
export interface FilterParams {
  category?: string;               // 類別篩選
  usable_item?: string;             // 可使用項目篩選
  maxPrice?: number;                // 最高價格
  minPrice?: number;                // 最低價格
  lat?: number;                     // 使用者緯度
  lng?: number;                     // 使用者經度
  radius?: number;                  // 搜尋半徑（公里），預設 10
  liked?: boolean;                  // 只顯示收藏的店家
  userId?: string;                  // 使用者 ID（用於 liked 篩選）
}

/**
 * API 成功回應格式
 */
export interface ApiSuccessResponse<T> {
  success: true;
  data: T;
  count?: number;
  filters?: FilterParams;
}

/**
 * API 錯誤回應格式
 */
export interface ApiErrorResponse {
  success: false;
  error: string;
}

/**
 * API 回應類型（成功或錯誤）
 */
export type ApiResponse<T> = ApiSuccessResponse<T> | ApiErrorResponse;

