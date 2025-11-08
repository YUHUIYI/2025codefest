const path = require('path');
const https = require('https');
require('dotenv').config();

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

const admin = requireFromFunctions('firebase-admin');

// 初始化 Firebase Admin
const projectId = process.env.GCLOUD_PROJECT || 'dongzhi-taipei';

if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FUNCTIONS_EMULATOR === 'true') {
  admin.initializeApp({ projectId: projectId });
} else {
  try {
    admin.initializeApp({ projectId: projectId });
  } catch (error) {
    console.error('Firebase Admin 初始化失敗:', error);
    process.exit(1);
  }
}

const db = admin.firestore();

/**
 * 使用 Google Geocoding API 將地址轉換為座標
 */
async function geocodeAddress(address) {
  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  
  if (!apiKey || apiKey === 'YOUR_API_KEY_HERE') {
    console.warn('⚠️  未設定 GOOGLE_MAPS_API_KEY');
    return null;
  }
  
  return new Promise((resolve) => {
    const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(address)}&key=${apiKey}&language=zh-TW&region=tw`;
    
    https.get(url, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          const result = JSON.parse(data);
          
          if (result.status === 'OK' && result.results.length > 0) {
            const location = result.results[0].geometry.location;
            resolve(new admin.firestore.GeoPoint(location.lat, location.lng));
          } else {
            console.warn(`⚠️  Geocoding 失敗 (${result.status}): ${address}`);
            resolve(null);
          }
        } catch (error) {
          console.error(`❌ 解析 Geocoding 回應失敗: ${address}`, error);
          resolve(null);
        }
      });
    }).on('error', (error) => {
      console.error(`❌ Geocoding API 請求失敗: ${address}`, error);
      resolve(null);
    });
  });
}

/**
 * 修正指定店家的地址和座標
 */
async function fixStoreAddress(storeName, correctAddress) {
  try {
    console.log(`\n🔍 搜尋店家: ${storeName}`);
    
    // 查詢店家
    const snapshot = await db.collection('stores')
      .where('store_name', '==', storeName)
      .limit(1)
      .get();
    
    if (snapshot.empty) {
      console.log(`❌ 找不到店家: ${storeName}`);
      return false;
    }
    
    const doc = snapshot.docs[0];
    const storeData = doc.data();
    
    console.log(`✅ 找到店家: ${doc.id}`);
    console.log(`   原地址: ${storeData.address}`);
    console.log(`   新地址: ${correctAddress}`);
    
    // 取得新座標
    console.log(`🌍 正在 geocoding...`);
    const location = await geocodeAddress(correctAddress);
    
    if (!location) {
      console.log(`❌ 無法取得座標`);
      return false;
    }
    
    console.log(`✅ 取得座標: (${location.latitude}, ${location.longitude})`);
    
    // 更新 Firestore
    await doc.ref.update({
      address: correctAddress,
      location: location,
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`✅ 更新完成`);
    return true;
    
  } catch (error) {
    console.error(`❌ 處理失敗:`, error);
    return false;
  }
}

/**
 * 主程式
 */
async function main() {
  console.log('╔═══════════════════════════════════════╗');
  console.log('║   修正店家地址與座標工具             ║');
  console.log('╚═══════════════════════════════════════╝\n');
  
  const storesToFix = [
    {
      name: '好時光女生運動樂園 西湖樂園',
      address: '114 臺北市內湖區西湖里內湖路一段319號2樓、321號2樓'
    },
    {
      name: '好時光女生運動樂園 大安樂園',
      address: '106 臺北市大安區復興南路一段249號4樓'
    },
    {
      name: '好時光女生運動樂園 松江樂園',
      address: '104 臺北市中山區興雅里長安東路二段49號2樓'
    }
  ];
  
  let successCount = 0;
  
  for (const store of storesToFix) {
    const success = await fixStoreAddress(store.name, store.address);
    if (success) {
      successCount++;
    }
    // 延遲避免超過 API rate limit
    await new Promise(resolve => setTimeout(resolve, 200));
  }
  
  console.log(`\n╔═══════════════════════════════════════╗`);
  console.log(`║   完成！成功修正 ${successCount}/${storesToFix.length} 筆資料           ║`);
  console.log(`╚═══════════════════════════════════════╝\n`);
  
  process.exit(0);
}

main().catch((error) => {
  console.error('執行錯誤:', error);
  process.exit(1);
});

