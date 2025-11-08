import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import express from 'express';
import cors from 'cors';
import { Request, Response } from 'express';
import {
  getAllStores,
  getStoreById,
  filterStores,
  toggleLike,
  addOrUpdateFields,
  updateStore,
} from './api/stores';
import { getAllProducts } from './api/products';

// 初始化 Firebase Admin
// 在 Emulator 環境中，連接到本地 Firestore Emulator
if (process.env.FUNCTIONS_EMULATOR === 'true' || process.env.FIRESTORE_EMULATOR_HOST) {
  admin.initializeApp({
    projectId: process.env.GCLOUD_PROJECT || 'dongzhi-taipei',
  });
} else {
  admin.initializeApp();
}

// 建立 Express 應用
const app = express();

// 設定 CORS（允許所有來源，實際部署時可限制特定網域）
app.use(cors({ origin: true }));
app.use(express.json());

// API Routes
app.get('/stores', getAllStores);
app.get('/stores/filter', filterStores);
app.get('/stores/:id', getStoreById);
app.post('/stores/:id/like', toggleLike);
app.post('/stores/:id/fields', addOrUpdateFields);
app.patch('/stores/:id', updateStore);
app.get('/products', getAllProducts);

// 健康檢查端點
app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// 匯出為 Cloud Function 2nd Gen（指定區域為 asia-east1）
export const api = functions.https.onRequest(
  {
    region: 'asia-east1',
    cors: true,
  },
  app
);

