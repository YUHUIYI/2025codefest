const path = require('path');
const fs = require('fs');

// 使用 functions 目錄的 node_modules
const functionsNodeModules = path.join(__dirname, 'functions', 'node_modules');

// 使用 require.resolve 來找到模組的實際路徑
function requireFromFunctions(moduleName) {
  try {
    const modulePath = require.resolve(moduleName, { paths: [functionsNodeModules] });
    return require(modulePath);
  } catch (error) {
    // 如果是子模組（如 csv-parse/sync），需要特殊處理
    if (moduleName.includes('/')) {
      const [parentModule, subModule] = moduleName.split('/');
      const parentPath = require.resolve(parentModule, { paths: [functionsNodeModules] });
      const subPath = path.join(path.dirname(parentPath), subModule);
      return require(subPath);
    }
    throw error;
  }
}

// 載入套件
const admin = requireFromFunctions('firebase-admin');
const { parse } = requireFromFunctions('csv-parse/sync');

// 初始化 Firebase Admin
const projectId = process.env.GCLOUD_PROJECT || 'dongzhi-taipei';

// 檢查是否在本地環境（使用 Firestore Emulator）
if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FUNCTIONS_EMULATOR === 'true') {
  admin.initializeApp({
    projectId: projectId,
  });
} else {
  // 生產環境：需要服務帳號金鑰或應用程式預設憑證
  try {
    // 嘗試使用應用程式預設憑證，並明確指定 Project ID
    admin.initializeApp({
      projectId: projectId,
    });
  } catch (error) {
    console.error('Firebase Admin 初始化失敗:', error);
    console.log('提示：');
    console.log('1. 如果是本地測試，請啟動 Firestore Emulator');
    console.log('2. 如果是生產環境，請確保已設置 Google Cloud 憑證');
    console.log('   可以通過以下方式之一設置：');
    console.log('   - 設置環境變數 GOOGLE_APPLICATION_CREDENTIALS 指向服務帳號金鑰 JSON 檔案');
    console.log('   - 或使用 gcloud auth application-default login');
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
      relax_column_count: true,  // 允許欄位數量不一致
      skip_records_with_error: true,  // 跳過有錯誤的記錄
      relax_quotes: true,  // 允許引號內的逗號
      quote: '"',  // 指定引號字符
    });

    console.log(`找到 ${records.length} 筆資料`);

    // 取得要上傳的資料範圍（startRow 和 endRow 是 1-based，對應 CSV 行號）
    // 因為第一行是標題，所以實際資料從索引 0 開始
    // startRow=1 表示第一筆資料（索引 0），endRow=2 表示第二筆資料（索引 1）
    // endRow=-1 表示上傳所有資料
    const startIndex = Math.max(0, startRow - 1);
    const actualEndRow = endRow === -1 ? records.length : endRow;
    const endIndex = Math.min(records.length, actualEndRow);
    const storesToUpload = records.slice(startIndex, endIndex);

    const rangeText = endRow === -1 ? `第 ${startRow}-${records.length} 行（全部）` : `第 ${startRow}-${endRow} 行`;
    console.log(`準備上傳${rangeText}資料（共 ${storesToUpload.length} 筆）...`);

    if (storesToUpload.length === 0) {
      console.log('⚠️  沒有資料需要上傳');
      return;
    }

    // Firestore batch write 限制為每次最多 500 筆
    const BATCH_SIZE = 500;
    let totalCount = 0;
    let skippedCount = 0;

    // 分批處理
    for (let batchStart = 0; batchStart < storesToUpload.length; batchStart += BATCH_SIZE) {
      const batchEnd = Math.min(batchStart + BATCH_SIZE, storesToUpload.length);
      const batch = db.batch();
      let batchCount = 0;

      console.log(`\n處理批次 ${Math.floor(batchStart / BATCH_SIZE) + 1}（第 ${batchStart + 1}-${batchEnd} 筆）...`);

      for (let i = batchStart; i < batchEnd; i++) {
        const record = storesToUpload[i];
        try {
          const storeData = mapCsvToStore(record);

          // 驗證必要欄位
          if (!storeData.store_name || !storeData.address) {
            console.log(`⚠️  跳過第 ${startRow + i} 行：缺少必要欄位（名稱或地址）`);
            skippedCount++;
            continue;
          }

          const storeRef = db.collection('stores').doc();
          batch.set(storeRef, storeData);
          batchCount++;
          totalCount++;

          if ((i + 1) % 50 === 0 || i === batchEnd - 1) {
            process.stdout.write(`\r  進度: ${i + 1}/${storesToUpload.length} (${Math.round((i + 1) / storesToUpload.length * 100)}%)`);
          }
        } catch (error) {
          console.error(`\n❌ 處理第 ${startRow + i} 行時發生錯誤:`, error);
          skippedCount++;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
        console.log(`\n  ✅ 批次 ${Math.floor(batchStart / BATCH_SIZE) + 1} 完成：上傳 ${batchCount} 筆`);
      }
    }

    console.log(`\n\n✅ 全部完成！成功上傳 ${totalCount} 筆資料到 Firestore`);
    if (skippedCount > 0) {
      console.log(`⚠️  跳過 ${skippedCount} 筆資料（缺少必要欄位或發生錯誤）`);
    }
  } catch (error) {
    console.error('❌ 上傳失敗:', error);
    process.exit(1);
  }
}

// 主程式
const csvFile = process.argv[2] || path.join(__dirname, 'scraper/vendors_formatted.csv');
const startRow = parseInt(process.argv[3]) || 1;
let endRow = process.argv[4];

// 處理 'all' 參數
if (endRow === 'all' || endRow === 'ALL') {
  endRow = -1;
} else {
  endRow = parseInt(endRow) || 2;
}

const rangeText = endRow === -1 ? '全部資料' : `第 ${startRow}-${endRow} 行`;

console.log('=== Firestore 資料上傳腳本 ===');
console.log(`CSV 檔案: ${csvFile}`);
console.log(`上傳範圍: ${rangeText}\n`);

uploadStores(csvFile, startRow, endRow)
  .then(() => {
    console.log('\n完成');
    process.exit(0);
  })
  .catch((error) => {
    console.error('發生錯誤:', error);
    process.exit(1);
  });

