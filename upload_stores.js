const path = require('path');
const fs = require('fs');

// 使用 functions 目錄的 node_modules
const functionsNodeModules = path.join(__dirname, 'functions', 'node_modules');

// 直接從 functions/node_modules 載入套件
const admin = require(path.join(functionsNodeModules, 'firebase-admin'));
const { parse } = require(path.join(functionsNodeModules, 'csv-parse', 'sync'));

// 初始化 Firebase Admin
// 檢查是否在本地環境（使用 Firestore Emulator）
if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FUNCTIONS_EMULATOR === 'true') {
  admin.initializeApp({
    projectId: process.env.GCLOUD_PROJECT || 'dongzhi-taipei',
  });
} else {
  // 生產環境：需要服務帳號金鑰
  // 如果沒有設定，會使用應用程式預設憑證
  try {
    admin.initializeApp();
  } catch (error) {
    console.error('Firebase Admin 初始化失敗:', error);
    console.log('提示：如果是本地測試，請啟動 Firestore Emulator');
    process.exit(1);
  }
}

const db = admin.firestore();

// CSV 欄位對應
function mapCsvToStore(row) {
  return {
    store_name: row['商家名稱']?.trim() || null,
    address: row['地址']?.trim() || null,
    phone: row['營業電話']?.trim() || null,
    businessHours: row['營業時間']?.trim() || null,
    website: row['網址']?.trim() || null,
    description: row['描述']?.trim() || null,
    category: row['類別']?.trim() || null,
    image_url: null, // CSV 沒有此欄位
    is_active: true,
    location: new admin.firestore.GeoPoint(0, 0), // 預設 [0° N, 0° E]
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function uploadStores(csvFilePath, startRow = 1, endRow = 2) {
  try {
    console.log(`讀取 CSV 檔案: ${csvFilePath}`);
    const fileContent = fs.readFileSync(csvFilePath, 'utf-8');

    // 解析 CSV
    const records = parse(fileContent, {
      columns: true,
      skip_empty_lines: true,
      trim: true,
    });

    console.log(`找到 ${records.length} 筆資料`);

    // 取得要上傳的資料範圍（startRow 和 endRow 是 1-based，對應 CSV 行號）
    // 因為第一行是標題，所以實際資料從索引 0 開始
    // startRow=1 表示第一筆資料（索引 0），endRow=2 表示第二筆資料（索引 1）
    const startIndex = Math.max(0, startRow - 1);
    const endIndex = Math.min(records.length, endRow);
    const storesToUpload = records.slice(startIndex, endIndex);

    console.log(`準備上傳第 ${startRow}-${endRow} 行資料（共 ${storesToUpload.length} 筆）...`);

    if (storesToUpload.length === 0) {
      console.log('⚠️  沒有資料需要上傳');
      return;
    }

    const batch = db.batch();
    let count = 0;

    for (let i = 0; i < storesToUpload.length; i++) {
      const record = storesToUpload[i];
      try {
        const storeData = mapCsvToStore(record);

        // 驗證必要欄位
        if (!storeData.store_name || !storeData.address) {
          console.log(`⚠️  跳過第 ${startRow + i} 行：缺少必要欄位（名稱或地址）`);
          continue;
        }

        const storeRef = db.collection('stores').doc();
        batch.set(storeRef, storeData);
        count++;

        console.log(`✓ 準備上傳: ${storeData.store_name}`);
        console.log(`  地址: ${storeData.address}`);
        console.log(`  類別: ${storeData.category || '無'}`);
      } catch (error) {
        console.error(`❌ 處理第 ${startRow + i} 行時發生錯誤:`, error);
      }
    }

    if (count > 0) {
      await batch.commit();
      console.log(`\n✅ 成功上傳 ${count} 筆資料到 Firestore！`);
    } else {
      console.log('\n⚠️  沒有資料被上傳');
    }
  } catch (error) {
    console.error('❌ 上傳失敗:', error);
    process.exit(1);
  }
}

// 主程式
const csvFile = process.argv[2] || path.join(__dirname, 'scraper/vendors_formatted.csv');
const startRow = parseInt(process.argv[3]) || 1;
const endRow = parseInt(process.argv[4]) || 2;

console.log('=== Firestore 資料上傳腳本 ===');
console.log(`CSV 檔案: ${csvFile}`);
console.log(`上傳範圍: 第 ${startRow}-${endRow} 行\n`);

uploadStores(csvFile, startRow, endRow)
  .then(() => {
    console.log('\n完成');
    process.exit(0);
  })
  .catch((error) => {
    console.error('發生錯誤:', error);
    process.exit(1);
  });

