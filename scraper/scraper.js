const puppeteer = require('puppeteer');
const createCsvWriter = require('csv-writer').createObjectCsvWriter;

const BASE_URL = 'https://500.gov.tw/FOAS/actions/Vendor114.action?view';

// 輔助函數：替代已移除的 waitForTimeout
function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// CSV 寫入器設定
const csvWriter = createCsvWriter({
  path: 'vendors_2.csv',
  header: [
    { id: 'name', title: '商家名稱' },
    { id: 'address', title: '地址' },
    { id: 'phone', title: '營業電話' },
    { id: 'businessHours', title: '營業時間' },
    { id: 'website', title: '網址' },
    { id: 'description', title: '描述' },
    { id: 'category', title: '類別' },
  ],
  encoding: 'utf8',
});

async function scrapeVendors() {
  console.log('啟動瀏覽器...');
  
  let browser;
  let retries = 3;
  
  // 嘗試啟動瀏覽器，加入重試機制
  while (retries > 0) {
    try {
      // 嘗試使用 headless 模式，更穩定
      browser = await puppeteer.launch({
        headless: 'new', // 使用新的 headless 模式，更穩定
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--disable-accelerated-2d-canvas',
          '--disable-gpu',
          '--disable-software-rasterizer',
        ],
        timeout: 60000, // 增加超時時間
        protocolTimeout: 120000, // 增加協議超時時間
      });
      console.log('✓ 瀏覽器啟動成功');
      break;
    } catch (error) {
      retries--;
      console.error(`瀏覽器啟動失敗，剩餘重試次數: ${retries}`, error.message);
      if (retries === 0) {
        console.error('無法啟動瀏覽器，請檢查系統設定');
        throw error;
      }
      await delay(2000); // 等待 2 秒後重試
    }
  }

  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1920, height: 1080 });
    
    console.log('前往目標網頁...');
    await page.goto(BASE_URL, { waitUntil: 'networkidle2', timeout: 60000 });
    console.log('✓ 頁面載入完成');

    // 等待頁面載入
    await delay(2000);

    // 選擇縣市 = 臺北市
    console.log('選擇縣市：臺北市...');
    try {
      // 等待下拉選單出現
      await delay(1000);
      
      // 嘗試多種選擇器來找到縣市下拉選單
      const citySelectors = [
        'select[name*="city"]',
        'select[name*="City"]',
        'select[id*="city"]',
        'select[id*="City"]',
        'select',
      ];
      
      let citySelected = false;
      let selectedSelector = null;
      
      for (const selector of citySelectors) {
        try {
          await page.waitForSelector(selector, { timeout: 3000 });
          const options = await page.$$eval(`${selector} option`, options => 
            options.map(opt => ({
              text: opt.textContent.trim(),
              value: opt.value || opt.textContent.trim()
            }))
          );
          console.log(`找到下拉選單，選項: ${options.slice(0, 5).map(o => o.text).join(', ')}...`);
          
          // 尋找「臺北市」選項
          const taipeiOption = options.find(opt => 
            opt.text.includes('臺北市') || opt.text.includes('台北市')
          );
          
          if (taipeiOption) {
            // 嘗試使用 value 或 text 來選擇
            try {
              // 先嘗試用 value
              if (taipeiOption.value && taipeiOption.value !== taipeiOption.text) {
                await page.select(selector, taipeiOption.value);
              } else {
                // 如果 value 和 text 一樣，直接用 text
                await page.select(selector, taipeiOption.text);
              }
              
              citySelected = true;
              selectedSelector = selector;
              console.log(`✓ 已選擇: ${taipeiOption.text}`);
              
              // 確認選擇成功
              await delay(500);
              const selectedValue = await page.evaluate((sel) => {
                const select = document.querySelector(sel);
                if (select) {
                  const selectedIndex = select.selectedIndex;
                  return {
                    text: select.options[selectedIndex].textContent.trim(),
                    value: select.options[selectedIndex].value
                  };
                }
                return null;
              }, selector);
              
              if (selectedValue && (selectedValue.text.includes('臺北市') || selectedValue.text.includes('台北市'))) {
                console.log(`✓ 確認選擇成功: ${selectedValue.text}`);
              } else {
                console.log(`⚠ 選擇可能失敗，當前值: ${selectedValue ? selectedValue.text : 'null'}`);
                citySelected = false; // 標記為失敗，繼續嘗試
              }
              
              if (citySelected) break;
            } catch (selectError) {
              console.log(`  選擇失敗: ${selectError.message}`);
            }
          }
        } catch (e) {
          // 繼續嘗試下一個選擇器
          console.log(`  選擇器 ${selector} 失敗: ${e.message}`);
        }
      }
      
      // 如果自動選擇失敗，嘗試用 JavaScript 選擇
      if (!citySelected) {
        console.log('嘗試使用 JavaScript 選擇...');
        const jsSelected = await page.evaluate(() => {
          const selects = document.querySelectorAll('select');
          for (const select of selects) {
            for (let i = 0; i < select.options.length; i++) {
              const optionText = select.options[i].textContent.trim();
              if (optionText.includes('臺北市') || optionText.includes('台北市')) {
                select.selectedIndex = i;
                // 觸發 change 事件
                const event = new Event('change', { bubbles: true });
                select.dispatchEvent(event);
                // 也觸發 input 事件（有些網站需要）
                const inputEvent = new Event('input', { bubbles: true });
                select.dispatchEvent(inputEvent);
                return {
                  success: true,
                  selectedText: optionText
                };
              }
            }
          }
          return { success: false };
        });
        
        if (jsSelected.success) {
          citySelected = true;
          console.log(`✓ 已透過 JavaScript 選擇: ${jsSelected.selectedText}`);
          await delay(500);
        } else {
          console.log('⚠ JavaScript 選擇也失敗');
        }
      }
      
      if (!citySelected) {
        throw new Error('無法選擇臺北市，請檢查頁面結構');
      }
    } catch (error) {
      console.error('選擇縣市時發生錯誤:', error.message);
      throw error;
    }
    
    await delay(1000);

    // 確認選擇的縣市
    const selectedCity = await page.evaluate(() => {
      const selects = document.querySelectorAll('select');
      for (const select of selects) {
        if (select.selectedIndex > 0) {
          return select.options[select.selectedIndex].textContent.trim();
        }
      }
      return null;
    });
    console.log(`✓ 確認已選擇: ${selectedCity || '未選擇'}`);

    // 點擊搜尋按鈕（黃色按鈕，有放大鏡圖示）
    console.log('點擊搜尋按鈕...');
    let searchClicked = false;
    
    // 方法1: 尋找黃色搜尋按鈕（根據截圖，是帶放大鏡圖示的按鈕）
    try {
      // 先等待按鈕出現
      await delay(1000);
      
      const searchButton = await page.evaluate(() => {
        // 尋找所有可能的搜尋按鈕
        const allButtons = Array.from(document.querySelectorAll('button, input[type="button"], input[type="submit"], a'));
        
        for (const btn of allButtons) {
          // 檢查是否有放大鏡圖示
          const hasMagnifier = btn.querySelector('img[src*="search"], img[src*="查詢"], img[alt*="查詢"], img[alt*="搜尋"]') ||
                              btn.querySelector('svg') ||
                              (btn.style && btn.style.backgroundColor && btn.style.backgroundColor.includes('yellow'));
          
          // 檢查文字內容
          const text = (btn.textContent || btn.value || btn.alt || '').trim();
          const hasSearchText = text.includes('搜尋') || text.includes('查詢');
          
          // 檢查是否有放大鏡圖示的父元素
          const img = btn.querySelector('img');
          const hasSearchIcon = img && (img.alt || '').includes('查詢');
          
          // 如果是黃色按鈕或包含搜尋相關文字/圖示
          if (hasMagnifier || hasSearchText || hasSearchIcon) {
            return {
              element: btn,
              text: text,
              tag: btn.tagName,
            };
          }
        }
        
        // 如果找不到，嘗試找所有按鈕，看哪個是黃色的
        for (const btn of allButtons) {
          const style = window.getComputedStyle(btn);
          const bgColor = style.backgroundColor;
          // 檢查是否是黃色系
          if (bgColor.includes('rgb(255, 193, 7)') || 
              bgColor.includes('rgb(255, 235, 59)') ||
              bgColor.includes('yellow') ||
              btn.classList.toString().includes('yellow') ||
              btn.style.backgroundColor === 'yellow') {
            return {
              element: btn,
              text: (btn.textContent || btn.value || '').trim(),
              tag: btn.tagName,
            };
          }
        }
        
        return null;
      });
      
      if (searchButton) {
        console.log(`  找到搜尋按鈕: ${searchButton.tag} - "${searchButton.text}"`);
        // 使用 JavaScript 點擊，更可靠
        await page.evaluate((btnInfo) => {
          // 重新找到按鈕並點擊
          const buttons = Array.from(document.querySelectorAll('button, input[type="button"], input[type="submit"], a'));
          for (const btn of buttons) {
            const text = (btn.textContent || btn.value || '').trim();
            const hasMagnifier = btn.querySelector('img[src*="search"], img[alt*="查詢"], img[alt*="搜尋"]');
            if (text.includes('搜尋') || hasMagnifier) {
              btn.click();
              return;
            }
          }
        }, searchButton);
        
        searchClicked = true;
        console.log('✓ 已點擊搜尋按鈕');
      }
    } catch (e) {
      console.log('  方法1失敗:', e.message);
    }

    // 方法2: 如果方法1失敗，嘗試直接找表單並提交
    if (!searchClicked) {
      try {
        const form = await page.$('form');
        if (form) {
          console.log('  找到表單，嘗試提交...');
          await form.evaluate(form => form.submit());
          searchClicked = true;
          console.log('✓ 已提交表單（方法2）');
        }
      } catch (e) {
        console.log('  方法2失敗:', e.message);
      }
    }

    // 方法3: 使用更通用的方式尋找按鈕
    if (!searchClicked) {
      try {
        const clicked = await page.evaluate(() => {
          // 尋找所有按鈕和連結
          const elements = Array.from(document.querySelectorAll('button, input[type="button"], input[type="submit"], a, div[onclick]'));
          
          for (const el of elements) {
            // 檢查文字
            const text = (el.textContent || el.value || '').trim();
            // 檢查是否有放大鏡圖示
            const hasIcon = el.querySelector('img[alt*="查詢"], img[alt*="搜尋"], svg');
            // 檢查樣式（黃色背景）
            const style = window.getComputedStyle(el);
            const isYellow = style.backgroundColor.includes('255, 193') || 
                           style.backgroundColor.includes('255, 235') ||
                           style.backgroundColor.includes('yellow');
            
            if (text.includes('搜尋') || text.includes('查詢') || hasIcon || isYellow) {
              el.click();
              return true;
            }
          }
          return false;
        });
        
        if (clicked) {
          searchClicked = true;
          console.log('✓ 已點擊搜尋按鈕（方法3）');
        }
      } catch (e) {
        console.log('  方法3失敗:', e.message);
      }
    }

    if (!searchClicked) {
      console.log('⚠ 無法點擊搜尋按鈕，但繼續執行...');
    }

    // 等待搜尋結果載入
    console.log('等待搜尋結果載入...');
    await delay(3000);
    
    // 等待結果列表出現，並確認是台北市的結果
    try {
      await page.waitForSelector('tr, div:has-text("營業地址"), [class*="list"]', { timeout: 10000 });
      console.log('✓ 結果列表已出現');
      
      // 確認搜尋結果是台北市的
      const isTaipeiResults = await page.evaluate(() => {
        const text = document.body.textContent || '';
        // 檢查是否包含台北市的地址（通常以 1xx 開頭的郵遞區號）
        const hasTaipeiZip = /10[0-9]\s*臺北市/.test(text) || /11[0-9]\s*臺北市/.test(text);
        // 或者直接檢查是否包含「臺北市」
        const hasTaipei = text.includes('臺北市');
        return hasTaipei && hasTaipeiZip;
      });
      
      if (!isTaipeiResults) {
        console.log('⚠ 警告: 搜尋結果可能不是台北市的，繼續執行...');
      } else {
        console.log('✓ 確認搜尋結果為台北市');
      }
    } catch (e) {
      console.log('⚠ 等待結果載入中...');
    }
    
    await delay(2000);

    // 檢查頁面內容，確認是否有結果
    const pageInfo = await page.evaluate(() => {
      const text = document.body.textContent || '';
      const hasAddress = text.includes('營業地址');
      const hasVendor = text.includes('店家') || text.includes('商家');
      const hasResults = text.includes('結果') || text.includes('共');
      
      // 檢查是否有列表元素
      const hasList = document.querySelectorAll('tr, table, [class*="list"], [class*="result"]').length > 0;
      
      // 檢查是否有連結
      const links = Array.from(document.querySelectorAll('a[href*="seqno"]'));
      
      return {
        hasAddress,
        hasVendor,
        hasResults,
        hasList,
        linkCount: links.length,
        sampleText: text.substring(0, 500),
      };
    });
    
    console.log('頁面狀態檢查:');
    console.log(`  包含「營業地址」: ${pageInfo.hasAddress ? '✓' : '✗'}`);
    console.log(`  包含「店家/商家」: ${pageInfo.hasVendor ? '✓' : '✗'}`);
    console.log(`  有列表元素: ${pageInfo.hasList ? '✓' : '✗'}`);
    console.log(`  找到店家連結: ${pageInfo.linkCount} 個`);
    
    if (pageInfo.linkCount === 0) {
      console.log('\n⚠ 警告: 未找到任何店家連結！');
      console.log('頁面內容預覽:');
      console.log(pageInfo.sampleText.substring(0, 300));
      console.log('\n可能需要檢查：');
      console.log('1. 搜尋是否成功執行');
      console.log('2. 頁面是否完全載入');
      console.log('3. 選擇器是否正確');
    }
    
    // 等待結果列表出現（使用更寬鬆的選擇器）
    try {
      await page.waitForSelector('tr, div, table, [class*="list"], [class*="result"]', { timeout: 10000 });
      console.log('✓ 結果列表元素已出現');
    } catch (error) {
      console.log('⚠ 未找到特定結果元素，繼續嘗試提取...');
    }

    const vendors = [];
    
    console.log('\n開始從列表頁提取店家資料...');
    
    // 先檢查頁面結構，輸出調試信息
    const pageStructure = await page.evaluate(() => {
      const containers = Array.from(document.querySelectorAll('tr, div, li, table'));
      const withAddress = containers.filter(c => c.textContent.includes('營業地址'));
      const withTaipei = containers.filter(c => c.textContent.includes('臺北市'));
      
      // 取前 3 個包含「營業地址」的容器，輸出其結構
      const sampleContainers = withAddress.slice(0, 3).map(c => ({
        tag: c.tagName,
        className: c.className || '',
        id: c.id || '',
        textPreview: c.textContent.substring(0, 200),
        htmlPreview: c.innerHTML.substring(0, 300),
      }));
      
      return {
        totalContainers: containers.length,
        withAddress: withAddress.length,
        withTaipei: withTaipei.length,
        sampleContainers: sampleContainers,
      };
    });
    
    console.log('頁面結構分析:');
    console.log(`  總容器數: ${pageStructure.totalContainers}`);
    console.log(`  包含「營業地址」: ${pageStructure.withAddress}`);
    console.log(`  包含「臺北市」: ${pageStructure.withTaipei}`);
    console.log('\n前 3 個包含「營業地址」的容器預覽:');
    pageStructure.sampleContainers.forEach((sample, idx) => {
      console.log(`\n  [${idx + 1}] ${sample.tag} (class: ${sample.className}, id: ${sample.id})`);
      console.log(`  文字預覽: ${sample.textPreview.substring(0, 150)}...`);
    });
    
    // 從列表頁提取基本資訊（店名、地址、詳情頁連結）
    const vendorBasicInfo = await page.evaluate(() => {
      const vendors = [];
      const debugInfo = [];
      
      // 找到所有包含店家資訊的容器
      const containers = Array.from(document.querySelectorAll('tr, div, li'));
      
      debugInfo.push(`找到 ${containers.length} 個容器`);
      
      containers.forEach((container, idx) => {
        const text = container.textContent || '';
        
        // 檢查是否包含「營業地址」，表示這是一個店家項目
        if (!text.includes('營業地址')) {
          return; // 跳過非店家項目
        }
        
        // 檢查是否包含「臺北市」，確保是台北市的店家
        if (!text.includes('臺北市')) {
          return; // 跳過非台北市店家
        }
        
        const data = {
          name: '',
          address: '',
          detailUrl: '', // 詳情頁連結
        };
        
        // 提取商家名稱（通常是第一行，不包含「營業地址」等關鍵字）
        const lines = text.split('\n').map(line => line.trim()).filter(line => line.length > 0);
        
        for (const line of lines) {
          if (line && 
              !line.includes('營業地址') && 
              !line.includes('營業電話') && 
              !line.includes('營業時間') &&
              !line.includes('網址') &&
              !line.includes('地址：') &&
              !line.includes('電話：') &&
              !line.includes('時間：') &&
              !line.includes('列表模式') &&
              !line.includes('卡片模式') &&
              line.length < 200 &&
              line.length > 1) {
            // 檢查是否包含地址格式（郵遞區號），如果是則跳過
            if (!/^\d{3}\s*臺北市/.test(line)) {
              data.name = line;
              break; // 找到店名就停止
            }
          }
        }
        
        // 如果沒找到店名，嘗試從連結文字獲取
        if (!data.name) {
          const linkEl = container.querySelector('a[href*="seqno"]');
          if (linkEl) {
            const linkText = linkEl.textContent.trim();
            if (linkText && linkText.length < 200 && !linkText.includes('營業地址')) {
              data.name = linkText;
            }
          }
        }
        
        // 提取營業地址（只提取地址本身，排除「營業地址連結」等文字）
        const addressMatch = text.match(/營業地址[：:]\s*(\d{3}\s*臺北市[^\n\r]+?)(?:\s*營業地址連結|$)/);
        if (addressMatch && addressMatch[1]) {
          // 清理地址，移除多餘的文字
          let address = addressMatch[1].trim();
          // 移除「營業地址連結」等字樣
          address = address.replace(/\s*營業地址連結.*$/, '');
          address = address.replace(/\s*連結.*$/, '');
          data.address = address.trim();
        }
        
        // 提取詳情頁連結
        const detailLink = container.querySelector('a[href*="seqno"][href*="productList"]');
        if (detailLink) {
          let href = detailLink.getAttribute('href');
          if (href) {
            // 如果是完整的 URL，直接使用
            if (href.startsWith('http')) {
              data.detailUrl = href;
            } else {
              // 如果是相對路徑，需要構建完整 URL
              // 正確格式: https://500.gov.tw/FOAS/actions/Vendor114.action?productList&seqno=...
              if (href.startsWith('/')) {
                // 絕對路徑，直接加上域名
                href = `https://500.gov.tw${href}`;
              } else if (href.includes('Vendor114.action')) {
                // 如果已經包含 Vendor114.action，加上完整路徑
                href = `https://500.gov.tw/FOAS/actions/${href}`;
              } else if (href.startsWith('?')) {
                // 如果以 ? 開頭，是查詢參數，構建完整 URL（去掉開頭的 ?）
                const queryParams = href.substring(1);
                href = `https://500.gov.tw/FOAS/actions/Vendor114.action?${queryParams}`;
              } else if (href.includes('productList') && href.includes('seqno')) {
                // 如果包含查詢參數關鍵字，構建完整 URL
                href = `https://500.gov.tw/FOAS/actions/Vendor114.action?${href}`;
              } else {
                // 其他情況，嘗試加上完整路徑
                href = `https://500.gov.tw/FOAS/actions/${href}`;
              }
              data.detailUrl = href;
            }
          }
        }
        
        // 只添加有店名和地址的資料
        if (data.name && data.address && data.address.includes('臺北市')) {
          vendors.push(data);
        }
      });
      
      // 去重：根據店名去重（避免重複）
      const uniqueVendors = [];
      const seenNames = new Set();
      for (const vendor of vendors) {
        // 清理店名（去除可能的重複）
        let cleanName = vendor.name;
        const nameLength = cleanName.length;
        if (nameLength > 0) {
          const halfLength = Math.floor(nameLength / 2);
          const firstHalf = cleanName.substring(0, halfLength);
          const secondHalf = cleanName.substring(halfLength);
          if (firstHalf === secondHalf) {
            cleanName = firstHalf;
          }
        }
        
        if (!seenNames.has(cleanName)) {
          seenNames.add(cleanName);
          vendor.name = cleanName; // 更新為清理後的名稱
          uniqueVendors.push(vendor);
        }
      }
      
      return {
        vendors: uniqueVendors,
        debugInfo: debugInfo,
      };
    });
    
    const vendorsList = vendorBasicInfo.vendors || vendorBasicInfo;
    console.log(`\n✓ 從列表頁提取到 ${vendorsList.length} 個店家基本資訊`);
    
    // 檢查是否有分頁
    const paginationInfo = await page.evaluate(() => {
      const nextButton = Array.from(document.querySelectorAll('a, button')).find(el => {
        const text = el.textContent || '';
        return text.includes('下一頁') || text.includes('>') || text.includes('Next');
      });
      const pageInfo = document.body.textContent || '';
      const hasPageInfo = pageInfo.match(/共\s*(\d+)\s*筆|第\s*\d+\s*頁/);
      return {
        hasNext: nextButton !== undefined && !nextButton.disabled,
        pageInfo: hasPageInfo ? hasPageInfo[0] : null,
      };
    });
    
    if (paginationInfo.hasNext) {
      console.log(`⚠ 注意: 發現有下一頁，但目前只爬取第一頁的 ${vendorsList.length} 個店家`);
      console.log(`   如需爬取所有頁面，請告訴我`);
    }
    
    console.log(`\n開始進入詳情頁提取完整資料...\n`);
    
    // 逐個進入詳情頁提取完整資料
    for (let i = 0; i < vendorsList.length; i++) {
      const basicInfo = vendorsList[i];
      const progress = `[${i + 1}/${vendorsList.length}]`;
      console.log(`${progress} 正在爬取: "${basicInfo.name}"`);
      
      // 驗證基本資料
      if (!basicInfo.name || !basicInfo.address) {
        console.log(`  ⚠ 跳過資料不完整: ${basicInfo.name || '無店名'}`);
        continue;
      }
      
      // 確保地址包含臺北市
      if (!basicInfo.address.includes('臺北市')) {
        console.log(`  ⚠ 跳過非台北市: ${basicInfo.name}`);
        continue;
      }
      
      // 額外檢查：確保地址格式正確
      const addressPattern = /\d{3}\s*臺北市/;
      if (!addressPattern.test(basicInfo.address)) {
        console.log(`  ⚠ 地址格式異常: ${basicInfo.name} (${basicInfo.address})`);
        continue;
      }
      
      // 初始化完整資料（從列表頁獲取的資料）
      const vendorData = {
        name: basicInfo.name,
        address: basicInfo.address,
        phone: '',
        businessHours: '',
        website: '',
        description: '',
        category: '',
      };
      
      // 如果有詳情頁連結，進入詳情頁提取其他資訊
      if (basicInfo.detailUrl) {
        console.log(`  詳情頁 URL: ${basicInfo.detailUrl}`);
        // 驗證 URL 格式
        if (!basicInfo.detailUrl.includes('/FOAS/actions/')) {
          console.warn(`  ⚠ 警告: URL 可能不正確，缺少 /FOAS/actions/ 路徑`);
        }
        try {
          const detailPage = await browser.newPage();
          await detailPage.goto(basicInfo.detailUrl, { waitUntil: 'networkidle2', timeout: 30000 });
          await delay(2000);
          
          // 檢查頁面是否載入成功
          const pageCheck = await detailPage.evaluate(() => {
            const text = document.body.textContent || '';
            return {
              hasError: text.includes('回動滋網') || text.includes('目前領券很踴躍'),
              hasPhone: text.includes('營業電話'),
              hasHours: text.includes('營業時間'),
              hasWebsite: document.querySelectorAll('a[href^="http"]:not([href*="500.gov.tw"])').length > 0,
              hasDescription: text.length > 500,
              sampleText: text.substring(0, 300),
            };
          });
          
          console.log(`  頁面檢查: 錯誤頁面=${pageCheck.hasError}, 有電話=${pageCheck.hasPhone}, 有時間=${pageCheck.hasHours}, 有網址=${pageCheck.hasWebsite}, 有說明=${pageCheck.hasDescription}`);
          if (pageCheck.hasError) {
            console.log(`  ⚠ 這是錯誤頁面，跳過`);
            await detailPage.close();
          } else {
            // 從詳情頁提取：電話、時間、網址、說明、地址（確認地址格式）
            const detailData = await detailPage.evaluate(() => {
              const data = {
                phone: '',
                businessHours: '',
                website: '',
                description: '',
                category: '',
                address: '', // 也從詳情頁提取地址，確保格式正確
              };
              
              // 檢查是否是錯誤頁面
              const pageText = document.body.textContent || '';
              if (pageText.includes('回動滋網') || pageText.includes('目前領券很踴躍')) {
                return data; // 返回空資料
              }
              
              const allElements = Array.from(document.querySelectorAll('*'));
              
              // 提取營業地址（從詳情頁確認地址格式）
              const addressElements = allElements.filter(el => {
                const text = el.textContent || '';
                return text.includes('營業地址') && text.includes('臺北市');
              });
              
              if (addressElements.length > 0) {
                const addressEl = addressElements[0];
                const addressText = addressEl.textContent || '';
                // 提取地址，排除「營業地址連結」等文字
                const addressMatch = addressText.match(/營業地址[：:]\s*(\d{3}\s*臺北市[^\n\r]+?)(?:\s*營業地址連結|$)/);
                if (addressMatch && addressMatch[1]) {
                  let address = addressMatch[1].trim();
                  // 清理地址，移除多餘的文字
                  address = address.replace(/\s*營業地址連結.*$/, '');
                  address = address.replace(/\s*連結.*$/, '');
                  data.address = address.trim();
                }
              }
              
              // 提取營業電話
              const phoneElements = allElements.filter(el => {
                const text = el.textContent || '';
                return text.includes('營業電話');
              });
              
              if (phoneElements.length > 0) {
                const phoneEl = phoneElements[0];
                const phoneText = phoneEl.textContent || '';
                const match = phoneText.match(/營業電話[：:]\s*([^\n\r]+)/);
                if (match && match[1]) {
                  data.phone = match[1].trim();
                } else {
                  // 嘗試從下一個兄弟節點獲取
                  const nextSibling = phoneEl.nextElementSibling;
                  if (nextSibling) {
                    const siblingText = nextSibling.textContent.trim();
                    // 檢查是否是電話格式
                    if (/^0\d{1,2}[-]?\d+/.test(siblingText) || siblingText.length < 20) {
                      data.phone = siblingText;
                    }
                  }
                  // 嘗試從父元素的下一個兄弟節點獲取
                  if (!data.phone) {
                    const parent = phoneEl.parentElement;
                    if (parent && parent.nextElementSibling) {
                      const parentSiblingText = parent.nextElementSibling.textContent.trim();
                      if (/^0\d{1,2}[-]?\d+/.test(parentSiblingText) || parentSiblingText.length < 20) {
                        data.phone = parentSiblingText;
                      }
                    }
                  }
                }
              }
              
              // 提取營業時間
              const hoursElements = allElements.filter(el => {
                const text = el.textContent || '';
                return text.includes('營業時間');
              });
              
              if (hoursElements.length > 0) {
                const hoursEl = hoursElements[0];
                const hoursText = hoursEl.textContent || '';
                const match = hoursText.match(/營業時間[：:]\s*([^\n\r]+)/);
                if (match && match[1]) {
                  data.businessHours = match[1].trim();
                } else {
                  // 嘗試從下一個兄弟節點獲取
                  const nextSibling = hoursEl.nextElementSibling;
                  if (nextSibling) {
                    const siblingText = nextSibling.textContent.trim();
                    if (siblingText.length < 100 && (siblingText.includes(':') || siblingText.includes('：'))) {
                      data.businessHours = siblingText;
                    }
                  }
                  // 嘗試從父元素的下一個兄弟節點獲取
                  if (!data.businessHours) {
                    const parent = hoursEl.parentElement;
                    if (parent && parent.nextElementSibling) {
                      const parentSiblingText = parent.nextElementSibling.textContent.trim();
                      if (parentSiblingText.length < 100) {
                        data.businessHours = parentSiblingText;
                      }
                    }
                  }
                }
              }
              
              // 提取網址（尋找外部連結）
              // 方法1: 尋找包含「網址」文字的元素，然後從其附近獲取連結
              const websiteLabelElements = allElements.filter(el => {
                const text = el.textContent || '';
                return text.includes('網址') && (text.includes('網址：') || text.includes('網址:'));
              });
              
              if (websiteLabelElements.length > 0) {
                const websiteLabelEl = websiteLabelElements[0];
                // 在同一個元素內尋找連結
                const linkInLabel = websiteLabelEl.querySelector('a[href^="http"]');
                if (linkInLabel) {
                  const href = linkInLabel.getAttribute('href') || '';
                  if (href && !href.includes('500.gov.tw') && !href.includes('mailto:')) {
                    data.website = href;
                  }
                }
                // 如果沒找到，嘗試從下一個兄弟節點獲取
                if (!data.website) {
                  const nextSibling = websiteLabelEl.nextElementSibling;
                  if (nextSibling) {
                    const linkInSibling = nextSibling.querySelector('a[href^="http"]');
                    if (linkInSibling) {
                      const href = linkInSibling.getAttribute('href') || '';
                      if (href && !href.includes('500.gov.tw') && !href.includes('mailto:')) {
                        data.website = href;
                      }
                    }
                  }
                }
                // 如果還是沒找到，嘗試從父元素的下一個兄弟節點獲取
                if (!data.website) {
                  const parent = websiteLabelEl.parentElement;
                  if (parent) {
                    const linkInParent = parent.querySelector('a[href^="http"]');
                    if (linkInParent) {
                      const href = linkInParent.getAttribute('href') || '';
                      if (href && !href.includes('500.gov.tw') && !href.includes('mailto:')) {
                        data.website = href;
                      }
                    }
                  }
                }
              }
              
              // 方法2: 如果方法1沒找到，尋找所有外部連結（排除 500.gov.tw）
              if (!data.website) {
                const websiteLinks = Array.from(document.querySelectorAll('a[href^="http"]'));
                for (const link of websiteLinks) {
                  const href = link.getAttribute('href') || '';
                  if (href && !href.includes('500.gov.tw') && !href.includes('mailto:') && !href.includes('facebook.com') && !href.includes('line.me')) {
                    // 優先選擇看起來像官網的連結（包含常見域名）
                    if (href.includes('.com') || href.includes('.tw') || href.includes('.org')) {
                      data.website = href;
                      break;
                    }
                  }
                }
                // 如果還是沒找到，使用第一個外部連結
                if (!data.website) {
                  for (const link of websiteLinks) {
                    const href = link.getAttribute('href') || '';
                    if (href && !href.includes('500.gov.tw') && !href.includes('mailto:')) {
                      data.website = href;
                      break;
                    }
                  }
                }
              }
              
              // 提取類別（尋找包含「類別」或「_」的格式，例如「戶外運動類_馬拉松/路跑」）
              const categoryElements = allElements.filter(el => {
                const text = el.textContent || '';
                return text.includes('類別') || (text.includes('_') && (text.includes('類') || text.includes('運動')));
              });
              
              for (const el of categoryElements) {
                const text = el.textContent || '';
                // 尋找「類別：」或「類別:」後面的內容
                const categoryMatch = text.match(/類別[：:]\s*([^\n\r]+)/);
                if (categoryMatch && categoryMatch[1]) {
                  data.category = categoryMatch[1].trim();
                  break;
                }
                // 如果沒有「類別：」，尋找包含「_」的分類格式（例如「戶外運動類_馬拉松/路跑」）
                if (!data.category && text.includes('_')) {
                  const underscoreMatch = text.match(/([^_\n\r]+類_[^\n\r]+)/);
                  if (underscoreMatch && underscoreMatch[1]) {
                    data.category = underscoreMatch[1].trim();
                    break;
                  }
                }
              }
              
              // 如果還沒找到類別，嘗試從整個頁面文字中尋找
              if (!data.category) {
                const pageText = document.body.textContent || '';
                const categoryInPage = pageText.match(/類別[：:]\s*([^\n\r]+)/);
                if (categoryInPage && categoryInPage[1]) {
                  data.category = categoryInPage[1].trim();
                } else {
                  // 尋找包含「_」的分類格式
                  const underscoreMatch = pageText.match(/([^_\n\r]+類_[^\n\r]+)/);
                  if (underscoreMatch && underscoreMatch[1]) {
                    data.category = underscoreMatch[1].trim();
                  }
                }
              }
              
              // 提取說明（尋找「簡介：」之後的完整描述）
              // 方法1: 尋找包含「簡介：」的元素
              const introElements = allElements.filter(el => {
                const text = el.textContent || '';
                return text.includes('簡介：') || text.includes('簡介:');
              });
              
              if (introElements.length > 0) {
                const introEl = introElements[0];
                const introText = introEl.textContent || '';
                // 提取「簡介：」之後的內容
                const introMatch = introText.match(/簡介[：:]\s*([^\n\r]+(?:\n[^\n\r]+)*)/);
                if (introMatch && introMatch[1]) {
                  let description = introMatch[1].trim();
                  // 清理描述，移除多餘的空白和換行
                  description = description.replace(/\s+/g, ' ').trim();
                  // 如果描述太長，可能需要截斷（但先保留完整內容）
                  if (description.length > 50) {
                    data.description = description;
                  }
                }
                // 如果沒找到，嘗試從下一個兄弟節點獲取
                if (!data.description) {
                  const nextSibling = introEl.nextElementSibling;
                  if (nextSibling) {
                    const siblingText = nextSibling.textContent.trim();
                    if (siblingText.length > 50 && !siblingText.includes('營業地址') && !siblingText.includes('營業電話')) {
                      data.description = siblingText;
                    }
                  }
                }
                // 如果還是沒找到，嘗試從父元素獲取
                if (!data.description) {
                  const parent = introEl.parentElement;
                  if (parent) {
                    const parentText = parent.textContent || '';
                    const parentMatch = parentText.match(/簡介[：:]\s*([^\n\r]+(?:\n[^\n\r]+)*)/);
                    if (parentMatch && parentMatch[1]) {
                      let description = parentMatch[1].trim();
                      description = description.replace(/\s+/g, ' ').trim();
                      if (description.length > 50) {
                        data.description = description;
                      }
                    }
                  }
                }
              }
              
              // 方法2: 如果方法1沒找到，從整個頁面文字中提取「簡介：」之後的內容
              if (!data.description) {
                const pageText = document.body.textContent || '';
                const introMatch = pageText.match(/簡介[：:]\s*([^\n\r]+(?:\n[^\n\r]+)*)/);
                if (introMatch && introMatch[1]) {
                  let description = introMatch[1].trim();
                  // 移除「動滋券適用品項」之後的內容（如果有的話）
                  description = description.split('動滋券適用品項')[0].trim();
                  description = description.replace(/\s+/g, ' ').trim();
                  if (description.length > 50) {
                    data.description = description;
                  }
                }
              }
              
              // 方法3: 如果還是沒找到，尋找較長的描述文字（排除已知欄位）
              if (!data.description) {
                const descCandidates = Array.from(document.querySelectorAll('p, div, span'));
                for (const el of descCandidates) {
                  const text = el.textContent.trim();
                  if (text.length > 50 && 
                      text.length < 2000 && 
                      !text.includes('營業地址') && 
                      !text.includes('營業電話') && 
                      !text.includes('營業時間') &&
                      !text.includes('網址') &&
                      !text.includes('類別') &&
                      !text.includes('單位簡介') &&
                      !text.includes('簡介：') &&
                      !text.includes('動滋券適用品項') &&
                      (text.includes('，') || text.includes(',') || text.includes('。') || text.length > 100)) {
                    data.description = text;
                    break;
                  }
                }
              }
              
              return data;
            });
            
            // 輸出提取結果
            console.log(`  提取結果:`);
            console.log(`    電話: ${detailData.phone || '未找到'}`);
            console.log(`    時間: ${detailData.businessHours || '未找到'}`);
            console.log(`    網址: ${detailData.website || '未找到'}`);
            console.log(`    說明: ${detailData.description ? detailData.description.substring(0, 50) + '...' : '未找到'}`);
            console.log(`    類別: ${detailData.category || '未找到'}`);
            
            // 合併詳情頁資料
            vendorData.phone = detailData.phone;
            vendorData.businessHours = detailData.businessHours;
            vendorData.website = detailData.website;
            vendorData.description = detailData.description;
            vendorData.category = detailData.category;
            // 如果詳情頁有地址且格式正確，使用詳情頁的地址（更準確）
            if (detailData.address && detailData.address.includes('臺北市')) {
              vendorData.address = detailData.address;
            }
            
            await detailPage.close();
            await delay(1000); // 避免請求過快
          }
          
        } catch (error) {
          console.error(`  ✗ 訪問詳情頁錯誤: ${error.message}`);
          console.error(`    錯誤詳情: ${error.stack}`);
          // 即使詳情頁失敗，也保留基本資料
        }
      } else {
        console.log(`  ⚠ 沒有詳情頁連結，跳過提取詳細資料`);
      }
      
      vendors.push(vendorData);
      console.log(`  ✓ 成功: ${vendorData.name}`);
      if (vendorData.address) console.log(`    地址: ${vendorData.address}`);
      if (vendorData.phone) console.log(`    電話: ${vendorData.phone}`);
      if (vendorData.businessHours) console.log(`    時間: ${vendorData.businessHours}`);
      if (vendorData.website) console.log(`    網址: ${vendorData.website}`);
      if (vendorData.description) console.log(`    說明: ${vendorData.description.substring(0, 50)}...`);
      
      // 每 10 筆顯示進度
      if ((i + 1) % 10 === 0 || i === vendorsList.length - 1) {
        const percentage = Math.round(((i + 1) / vendorsList.length) * 100);
        console.log(`\n進度: ${percentage}% (${i + 1}/${vendorsList.length})\n`);
      }
    }

    console.log(`\n總共爬取 ${vendors.length} 個店家`);
    console.log('正在寫入 CSV 檔案...');

    // 寫入 CSV
    await csvWriter.writeRecords(vendors);
    console.log(`\n✓ CSV 檔案已生成: vendors_2.csv`);
    console.log(`總共寫入 ${vendors.length} 筆資料`);
    
    // 統計資料完整性
    const stats = {
      total: vendors.length,
      withPhone: vendors.filter(v => v.phone).length,
      withHours: vendors.filter(v => v.businessHours).length,
      withWebsite: vendors.filter(v => v.website).length,
      withDescription: vendors.filter(v => v.description).length,
      withCategory: vendors.filter(v => v.category).length,
    };
    console.log('\n資料完整性統計:');
    console.log(`  總數: ${stats.total}`);
    console.log(`  有電話: ${stats.withPhone} (${Math.round(stats.withPhone/stats.total*100)}%)`);
    console.log(`  有時間: ${stats.withHours} (${Math.round(stats.withHours/stats.total*100)}%)`);
    console.log(`  有網址: ${stats.withWebsite} (${Math.round(stats.withWebsite/stats.total*100)}%)`);
    console.log(`  有說明: ${stats.withDescription} (${Math.round(stats.withDescription/stats.total*100)}%)`);
    console.log(`  有類別: ${stats.withCategory} (${Math.round(stats.withCategory/stats.total*100)}%)`);

  } catch (error) {
    console.error('爬蟲執行錯誤:', error);
    console.error('錯誤詳情:', error.stack);
  } finally {
    if (browser) {
      try {
        await browser.close();
        console.log('瀏覽器已關閉');
      } catch (closeError) {
        console.error('關閉瀏覽器時發生錯誤:', closeError.message);
      }
    }
  }
}

// 執行爬蟲
scrapeVendors().catch(console.error);

