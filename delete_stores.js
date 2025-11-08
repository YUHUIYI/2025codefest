const path = require('path');
const readline = require('readline');

// 使用 functions 目錄的 node_modules
const functionsNodeModules = path.join(__dirname, 'functions', 'node_modules');

function requireFromFunctions(moduleName) {
  try {
    const modulePath = require.resolve(moduleName, { paths: [functionsNodeModules] });
    return require(modulePath);
  } catch (error) {
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

// 初始化 Firebase Admin
const projectId = process.env.GCLOUD_PROJECT || 'dongzhi-taipei';

// 檢查是否在本地環境（使用 Firestore Emulator）
if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FUNCTIONS_EMULATOR === 'true') {
  admin.initializeApp({
    projectId: projectId,
  });
  console.log('✅ 使用 Firestore Emulator');
} else {
  // 生產環境：需要服務帳號金鑰或應用程式預設憑證
  try {
    admin.initializeApp({
      projectId: projectId,
    });
    console.log('✅ 使用應用程式預設憑證');
  } catch (error) {
    console.error('❌ Firebase Admin 初始化失敗:', error);
    console.log('\n提示：');
    console.log('1. 如果是本地測試，請啟動 Firestore Emulator');
    console.log('2. 如果是生產環境，請確保已設置 Google Cloud 憑證');
    console.log('   可以通過以下方式之一設置：');
    console.log('   - 設置環境變數 GOOGLE_APPLICATION_CREDENTIALS 指向服務帳號金鑰 JSON 檔案');
    console.log('   - 或使用 gcloud auth application-default login');
    process.exit(1);
  }
}

const db = admin.firestore();

/**
 * 刪除整個 stores collection
 */
async function deleteAllStores() {
  const BATCH_SIZE = 500;
  const collectionRef = db.collection('stores');
  
  let totalDeleted = 0;
  let hasMore = true;
  
  console.log('\n🗑️  開始刪除 stores collection...\n');
  
  while (hasMore) {
    try {
      // 每次查詢最多 BATCH_SIZE 筆
      const snapshot = await collectionRef.limit(BATCH_SIZE).get();
      
      if (snapshot.empty) {
        hasMore = false;
        break;
      }
      
      // 建立批次刪除
      const batch = db.batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });
      
      // 提交批次刪除
      await batch.commit();
      totalDeleted += snapshot.size;
      
      console.log(`已刪除 ${totalDeleted} 筆資料...`);
      
      // 如果這次查詢的結果少於 BATCH_SIZE，表示已經沒有更多資料
      if (snapshot.size < BATCH_SIZE) {
        hasMore = false;
      }
    } catch (error) {
      console.error('❌ 刪除過程中發生錯誤:', error);
      throw error;
    }
  }
  
  console.log(`\n✅ 刪除完成！總共刪除 ${totalDeleted} 筆資料\n`);
}

/**
 * 刪除指定 ID 的店家
 */
async function deleteStoreById(storeId) {
  try {
    await db.collection('stores').doc(storeId).delete();
    console.log(`✅ 已刪除店家: ${storeId}`);
    return true;
  } catch (error) {
    console.error(`❌ 刪除失敗 (${storeId}):`, error);
    return false;
  }
}

/**
 * 批次刪除多筆資料（指定 ID）
 */
async function deleteStoresByIds(storeIds) {
  console.log(`\n準備刪除 ${storeIds.length} 筆資料...\n`);
  
  const BATCH_SIZE = 500;
  let totalDeleted = 0;
  
  // 分批處理
  for (let i = 0; i < storeIds.length; i += BATCH_SIZE) {
    const batchIds = storeIds.slice(i, Math.min(i + BATCH_SIZE, storeIds.length));
    const batch = db.batch();
    
    batchIds.forEach((storeId) => {
      const docRef = db.collection('stores').doc(storeId);
      batch.delete(docRef);
    });
    
    await batch.commit();
    totalDeleted += batchIds.length;
    console.log(`已刪除 ${totalDeleted} 筆資料...`);
  }
  
  console.log(`\n✅ 批次刪除完成！總共刪除 ${totalDeleted} 筆資料\n`);
}

/**
 * 根據條件查詢並刪除
 */
async function deleteStoresByCondition(fieldName, operator, value) {
  try {
    const snapshot = await db.collection('stores')
      .where(fieldName, operator, value)
      .get();
    
    console.log(`\n找到 ${snapshot.size} 筆符合條件的資料\n`);
    
    if (snapshot.empty) {
      console.log('沒有找到符合條件的資料');
      return;
    }
    
    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      console.log(`準備刪除: ${doc.id} - ${doc.data().store_name || 'N/A'}`);
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`\n✅ 刪除完成！總共刪除 ${snapshot.size} 筆資料\n`);
  } catch (error) {
    console.error('❌ 刪除失敗:', error);
  }
}

/**
 * 顯示統計資訊
 */
async function showStats() {
  try {
    const snapshot = await db.collection('stores').count().get();
    const count = snapshot.data().count;
    console.log(`\n📊 目前 stores collection 有 ${count} 筆資料\n`);
    return count;
  } catch (error) {
    console.error('❌ 無法取得統計資訊:', error);
    return 0;
  }
}

/**
 * 互動式選單
 */
async function showMenu() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  const question = (query) => new Promise((resolve) => rl.question(query, resolve));
  
  console.log('\n╔═══════════════════════════════════════╗');
  console.log('║   Firestore Stores 刪除工具           ║');
  console.log('╚═══════════════════════════════════════╝\n');
  
  await showStats();
  
  console.log('請選擇操作：');
  console.log('1. 刪除所有資料（整個 collection）');
  console.log('2. 刪除單筆資料（指定 ID）');
  console.log('3. 刪除多筆資料（指定多個 ID）');
  console.log('4. 根據條件刪除（例如：地址為空）');
  console.log('5. 只顯示統計資訊');
  console.log('0. 退出\n');
  
  const choice = await question('請輸入選項 (0-5): ');
  
  switch (choice.trim()) {
    case '1':
      const confirm = await question('\n⚠️  確定要刪除所有資料嗎？此操作無法復原！(yes/no): ');
      if (confirm.toLowerCase() === 'yes') {
        await deleteAllStores();
      } else {
        console.log('❌ 已取消操作');
      }
      break;
      
    case '2':
      const storeId = await question('請輸入店家 ID: ');
      await deleteStoreById(storeId.trim());
      break;
      
    case '3':
      const ids = await question('請輸入店家 ID（用逗號分隔）: ');
      const idArray = ids.split(',').map(id => id.trim()).filter(id => id);
      if (idArray.length > 0) {
        await deleteStoresByIds(idArray);
      } else {
        console.log('❌ 沒有輸入有效的 ID');
      }
      break;
      
    case '4':
      console.log('\n範例：刪除地址為空的店家');
      const field = await question('欄位名稱 (例如: address): ');
      const op = await question('運算子 (==, !=, <, >, <=, >=): ');
      const val = await question('值 (例如: 空字串請輸入 ""): ');
      
      let value = val.trim();
      if (value === '""' || value === "''") {
        value = '';
      }
      
      await deleteStoresByCondition(field.trim(), op.trim(), value);
      break;
      
    case '5':
      await showStats();
      break;
      
    case '0':
      console.log('👋 再見！');
      rl.close();
      process.exit(0);
      break;
      
    default:
      console.log('❌ 無效的選項');
  }
  
  rl.close();
}

// 主程式
async function main() {
  try {
    // 檢查命令列參數
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
      // 沒有參數，顯示互動式選單
      await showMenu();
    } else if (args[0] === '--all' || args[0] === '-a') {
      // 直接刪除所有資料
      console.log('⚠️  將刪除所有 stores 資料...');
      await deleteAllStores();
    } else if (args[0] === '--stats' || args[0] === '-s') {
      // 只顯示統計
      await showStats();
    } else if (args[0] === '--help' || args[0] === '-h') {
      // 顯示說明
      console.log('\n使用方式：');
      console.log('  node delete_stores.js              # 互動式選單');
      console.log('  node delete_stores.js --all        # 刪除所有資料');
      console.log('  node delete_stores.js --stats      # 顯示統計資訊');
      console.log('  node delete_stores.js --help       # 顯示此說明\n');
    } else {
      console.log('❌ 未知的參數，使用 --help 查看說明');
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ 執行錯誤:', error);
    process.exit(1);
  }
}

main();

