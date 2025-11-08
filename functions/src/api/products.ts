import { Request, Response } from 'express';
import * as admin from 'firebase-admin';
import { ProductResponse } from './types';

function getDb() {
  return admin.firestore();
}

/**
 * GET /api/products - 取得商品清單
 */
export async function getAllProducts(req: Request, res: Response): Promise<void> {
  try {
    const db = getDb();
    const snapshot = await db.collection('products').get();

    const products: ProductResponse[] = [];
    snapshot.forEach((doc) => {
      const data = doc.data();
      products.push({
        id: doc.id,
        product_name: (data.product_name ?? data.name ?? '').toString(),
        price: typeof data.price === 'number' ? data.price : Number(data.price) || 0,
        store_id: (data.store_id ?? data.storeId ?? '').toString(),
        store_name: (data.store_name ?? '').toString(),
      });
    });

    res.json({
      success: true,
      data: products,
      count: products.length,
    });
  } catch (error) {
    console.error('Error fetching products:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch products',
    });
  }
}

