import { FilterParams } from '../api/types';

/**
 * 驗證篩選參數
 * @param params 篩選參數
 * @returns 驗證後的參數，或錯誤訊息
 */
export function validateFilterParams(params: any): {
  valid: boolean;
  params?: FilterParams;
  error?: string;
} {
  const validated: FilterParams = {};

  // 驗證 category
  if (params.category !== undefined) {
    if (typeof params.category !== 'string') {
      return { valid: false, error: 'category must be a string' };
    }
    validated.category = params.category;
  }

  // 驗證 usable_item
  if (params.usable_item !== undefined) {
    if (typeof params.usable_item !== 'string') {
      return { valid: false, error: 'usable_item must be a string' };
    }
    validated.usable_item = params.usable_item;
  }

  // 驗證價格
  if (params.maxPrice !== undefined) {
    const maxPrice = Number(params.maxPrice);
    if (isNaN(maxPrice) || maxPrice < 0) {
      return { valid: false, error: 'maxPrice must be a positive number' };
    }
    validated.maxPrice = maxPrice;
  }

  if (params.minPrice !== undefined) {
    const minPrice = Number(params.minPrice);
    if (isNaN(minPrice) || minPrice < 0) {
      return { valid: false, error: 'minPrice must be a positive number' };
    }
    validated.minPrice = minPrice;
  }

  // 驗證位置和半徑
  if (params.lat !== undefined || params.lng !== undefined) {
    if (params.lat === undefined || params.lng === undefined) {
      return { valid: false, error: 'Both lat and lng must be provided for location filtering' };
    }
    const lat = Number(params.lat);
    const lng = Number(params.lng);
    if (isNaN(lat) || isNaN(lng)) {
      return { valid: false, error: 'lat and lng must be valid numbers' };
    }
    if (lat < -90 || lat > 90) {
      return { valid: false, error: 'lat must be between -90 and 90' };
    }
    if (lng < -180 || lng > 180) {
      return { valid: false, error: 'lng must be between -180 and 180' };
    }
    validated.lat = lat;
    validated.lng = lng;

    // 驗證半徑
    if (params.radius !== undefined) {
      const radius = Number(params.radius);
      if (isNaN(radius) || radius <= 0) {
        return { valid: false, error: 'radius must be a positive number' };
      }
      validated.radius = radius;
    } else {
      validated.radius = 10; // 預設 10 公里
    }
  }

  // 驗證收藏篩選
  if (params.liked !== undefined) {
    if (params.liked !== 'true' && params.liked !== 'false' && typeof params.liked !== 'boolean') {
      return { valid: false, error: 'liked must be a boolean' };
    }
    validated.liked = params.liked === 'true' || params.liked === true;
    if (validated.liked && !params.userId) {
      return { valid: false, error: 'userId is required when liked is true' };
    }
    if (params.userId) {
      if (typeof params.userId !== 'string') {
        return { valid: false, error: 'userId must be a string' };
      }
      validated.userId = params.userId;
    }
  }

  return { valid: true, params: validated };
}

