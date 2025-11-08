import { Request, Response } from 'express';
import * as admin from 'firebase-admin';
import { Store, FilterParams } from './types';
import { calculateDistance } from '../utils/distance';
import { validateFilterParams } from '../utils/validation';

// 延遲初始化，確保 admin.initializeApp() 已執行
function getDb() {
  return admin.firestore();
}

/**
 * GET /api/stores - 取得所有有效店家列表
 */
export async function getAllStores(req: Request, res: Response): Promise<void> {
  try {
    const db = getDb();
    const storesSnapshot = await db
      .collection('stores')
      .where('is_active', '==', true)
      .get();

    const stores: Store[] = [];
    storesSnapshot.forEach((doc) => {
      stores.push({
        id: doc.id,
        ...doc.data(),
      } as Store);
    });

    res.json({
      success: true,
      data: stores,
      count: stores.length,
    });
  } catch (error) {
    console.error('Error fetching stores:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch stores',
    });
  }
}

/**
 * GET /api/stores/:id - 取得單一店家詳情
 */
export async function getStoreById(req: Request, res: Response): Promise<void> {
  try {
    const db = getDb();
    const storeId = req.params.id;
    const storeDoc = await db.collection('stores').doc(storeId).get();

    if (!storeDoc.exists) {
      res.status(404).json({
        success: false,
        error: 'Store not found',
      });
      return;
    }

    res.json({
      success: true,
      data: {
        id: storeDoc.id,
        ...storeDoc.data(),
      },
    });
  } catch (error) {
    console.error('Error fetching store:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch store',
    });
  }
}

/**
 * GET /api/stores/filter - 依條件篩選店家
 */
export async function filterStores(req: Request, res: Response): Promise<void> {
  try {
    // 驗證參數
    const validation = validateFilterParams(req.query);
    if (!validation.valid) {
      res.status(400).json({
        success: false,
        error: validation.error,
      });
      return;
    }

    const params = validation.params as FilterParams;

    // 建立 Firestore 查詢
    const db = getDb();
    let query: admin.firestore.Query = db
      .collection('stores')
      .where('is_active', '==', true);

    // 類別篩選
    if (params.category) {
      query = query.where('category', '==', params.category);
    }

    // 可使用項目篩選
    if (params.usable_item) {
      query = query.where('usable_items', 'array-contains', params.usable_item);
    }

    const snapshot = await query.get();
    let stores: Store[] = [];

    snapshot.forEach((doc) => {
      const store = {
        id: doc.id,
        ...doc.data(),
      } as Store;
      stores.push(store);
    });

    // 價格篩選（在記憶體中處理，因為 Firestore 不支援多個範圍查詢）
    if (params.minPrice !== undefined) {
      stores = stores.filter((store) => store.price_range.min >= params.minPrice!);
    }
    if (params.maxPrice !== undefined) {
      stores = stores.filter((store) => store.price_range.max <= params.maxPrice!);
    }

    // 收藏篩選
    if (params.liked && params.userId) {
      stores = stores.filter(
        (store) => store.likedBy && store.likedBy.includes(params.userId!)
      );
    }

    // 距離篩選
    if (params.lat !== undefined && params.lng !== undefined) {
      stores = stores
        .map((store) => {
          const distance = calculateDistance(
            params.lat!,
            params.lng!,
            store.location.latitude,
            store.location.longitude
          );
          return {
            ...store,
            distance,
          };
        })
        .filter((store) => store.distance <= (params.radius || 10))
        .sort((a, b) => (a.distance || 0) - (b.distance || 0));
    }

    res.json({
      success: true,
      data: stores,
      count: stores.length,
      filters: params,
    });
  } catch (error) {
    console.error('Error filtering stores:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to filter stores',
    });
  }
}

/**
 * POST /api/stores/:id/like - 切換店家收藏狀態
 */
export async function toggleLike(req: Request, res: Response): Promise<void> {
  try {
    const storeId = req.params.id;
    const userId = req.body.userId;

    if (!userId) {
      res.status(400).json({
        success: false,
        error: 'userId is required',
      });
      return;
    }

    const db = getDb();
    const storeRef = db.collection('stores').doc(storeId);
    const storeDoc = await storeRef.get();

    if (!storeDoc.exists) {
      res.status(404).json({
        success: false,
        error: 'Store not found',
      });
      return;
    }

    const store = storeDoc.data() as Store;
    const likedBy = store.likedBy || [];
    const isLiked = likedBy.includes(userId);

    if (isLiked) {
      // 移除收藏
      await storeRef.update({
        likedBy: admin.firestore.FieldValue.arrayRemove(userId),
      });
    } else {
      // 加入收藏
      await storeRef.update({
        likedBy: admin.firestore.FieldValue.arrayUnion(userId),
      });
    }

    res.json({
      success: true,
      liked: !isLiked,
      message: isLiked ? 'Removed from favorites' : 'Added to favorites',
    });
  } catch (error) {
    console.error('Error toggling like:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to toggle like',
    });
  }
}

