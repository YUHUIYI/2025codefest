const puppeteer = require('puppeteer');
const createCsvWriter = require('csv-writer').createObjectCsvWriter;
const fs = require('fs');
const path = require('path');

const BASE_URL = 'https://500.gov.tw/FOAS/actions/Vendor114.action?view';

// 讀取 vendors.csv 文件，提取店家名稱和地址的對應關係
function readVendorData() {
  try {
    const filePath = path.join(__dirname, 'vendors.csv');
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n').map(line => line.trim()).filter(line => line.length > 0);
    
    const vendorData = new Map(); // 店名 -> 地址
    const vendorNames = [];
    
    // 奇數行（從0開始，所以是偶數索引）是店家名稱，下一行是地址
    for (let i = 0; i < lines.length; i += 2) {
      const name = lines[i];
      const address = lines[i + 1] || '';
      
      if (name && !name.startsWith('營業地址')) {
        vendorNames.push(name);
        // 清理地址格式：移除「營業地址:」前綴
        const cleanAddress = address.replace(/^營業地址[：:]\s*/, '').trim();
        vendorData.set(name, cleanAddress);
      }
    }
    
    console.log(`從 vendors.csv 讀取到 ${vendorNames.length} 個店家名稱和地址`);
    return { names: vendorNames, data: vendorData };
  } catch (error) {
    console.error('讀取 vendors.csv 失敗:', error.message);
    return { names: [], data: new Map() };
  }
}

// 輔助函數：替代已移除的 waitForTimeout
function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// CSV 寫入器設定
const csvWriter = createCsvWriter({
  path: 'vendors_5.csv',
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
  // 先讀取目標店家列表和地址對應關係
  const { names: targetVendorNames, data: vendorAddressMap } = readVendorData();
  if (targetVendorNames.length === 0) {
    console.error('未讀取到任何店家名稱，請檢查 vendors.csv 文件');
    return;
  }
  
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

    console.log('\n開始從列表頁提取所有店家資料...');
    
    // 先滾動頁面確保所有內容都載入（如果是動態載入）
    console.log('滾動頁面以載入所有內容（目標：至少450筆）...');
    let previousLinkCount = 0;
    let scrollAttempts = 0;
    const maxScrollAttempts = 50; // 增加最多滾動次數
    const targetLinkCount = 450; // 目標連結數量
    
    while (scrollAttempts < maxScrollAttempts) {
      // 滾動到底部
      await page.evaluate(async () => {
        window.scrollTo(0, document.body.scrollHeight);
        await new Promise(resolve => setTimeout(resolve, 500));
      });
      
      await delay(1500); // 增加等待時間，確保內容載入
      
      // 檢查連結數量是否增加
      const currentLinkCount = await page.evaluate(() => {
        return document.querySelectorAll('a[href*="seqno"]').length;
      });
      
      console.log(`  滾動 ${scrollAttempts + 1} 次，找到 ${currentLinkCount} 個連結`);
      
      // 如果達到目標數量，繼續滾動幾次確保所有資料都載入
      if (currentLinkCount >= targetLinkCount) {
        console.log(`  ✓ 已達到目標數量 ${targetLinkCount}，繼續滾動確保完整載入...`);
        // 再滾動3次確保所有資料都載入
        for (let i = 0; i < 3; i++) {
          await page.evaluate(async () => {
            window.scrollTo(0, document.body.scrollHeight);
            await new Promise(resolve => setTimeout(resolve, 500));
          });
          await delay(1500);
          const finalCount = await page.evaluate(() => {
            return document.querySelectorAll('a[href*="seqno"]').length;
          });
          console.log(`    額外滾動 ${i + 1} 次，找到 ${finalCount} 個連結`);
        }
        break;
      }
      
      if (currentLinkCount === previousLinkCount && currentLinkCount > 0) {
        // 連結數量沒有增加，可能已經載入完畢
        if (currentLinkCount < targetLinkCount) {
          console.log(`  ⚠ 連結數量穩定但未達目標（${currentLinkCount} < ${targetLinkCount}），繼續嘗試...`);
          // 再嘗試幾次
          if (scrollAttempts < maxScrollAttempts - 5) {
            previousLinkCount = currentLinkCount;
            scrollAttempts++;
            continue;
          }
        }
        console.log('  連結數量穩定，停止滾動');
        break;
      }
      
      previousLinkCount = currentLinkCount;
      scrollAttempts++;
    }
    
    // 最後一次滾動到底部
    await page.evaluate(() => {
      window.scrollTo(0, document.body.scrollHeight);
    });
    await delay(2000);
    
    const finalLinkCount = await page.evaluate(() => {
      return document.querySelectorAll('a[href*="seqno"]').length;
    });
    console.log(`✓ 頁面滾動完成，最終找到 ${finalLinkCount} 個連結`);
    
    // 從列表頁提取基本資訊（店名、詳情頁連結）
    // 只提取目標列表中的店家，地址從 vendors.csv 讀取
    const vendorBasicInfo = await page.evaluate((targetNames) => {
      const vendors = [];
      const seenUrls = new Set(); // 用於去重，根據詳情頁 URL
      
      // 清理店名：移除重複的部分
      const cleanVendorName = (name) => {
        if (!name) return '';
        let cleanName = name.trim();
        // 如果店名重複（例如 "店名店名"），只保留一半
        const nameLength = cleanName.length;
        if (nameLength > 0) {
          const halfLength = Math.floor(nameLength / 2);
          const firstHalf = cleanName.substring(0, halfLength);
          const secondHalf = cleanName.substring(halfLength);
          if (firstHalf === secondHalf) {
            cleanName = firstHalf;
          }
        }
        return cleanName;
      };
      
      // 創建一個函數來檢查店名是否在目標列表中（模糊匹配）
      const isTargetVendor = (name) => {
        if (!name) return false;
        const cleanName = cleanVendorName(name);
        // 精確匹配
        if (targetNames.includes(cleanName)) return true;
        // 模糊匹配：檢查目標名稱是否包含在店名中，或店名是否包含在目標名稱中
        for (const targetName of targetNames) {
          if (cleanName.includes(targetName) || targetName.includes(cleanName)) {
            return true;
          }
        }
        return false;
      };
      
      // 找到匹配的目標店名
      const findMatchingTargetName = (name) => {
        if (!name) return null;
        const cleanName = cleanVendorName(name);
        // 精確匹配
        if (targetNames.includes(cleanName)) return cleanName;
        // 模糊匹配
        for (const targetName of targetNames) {
          if (cleanName.includes(targetName) || targetName.includes(cleanName)) {
            return targetName;
          }
        }
        return null;
      };
      
      // 方法1: 優先尋找包含詳情頁連結的容器（更精確）
      // 嘗試多種選擇器
      let detailLinks = Array.from(document.querySelectorAll('a[href*="seqno"][href*="productList"]'));
      if (detailLinks.length === 0) {
        // 如果找不到，嘗試只找包含 seqno 的連結
        detailLinks = Array.from(document.querySelectorAll('a[href*="seqno"]'));
      }
      
      // 返回找到的連結數量用於調試
      const linkCount = detailLinks.length;
      
      // 收集所有連結信息用於調試
      const allLinksInfo = [];
      
      // 為每個詳情頁連結找到對應的店家容器
      detailLinks.forEach((link, index) => {
        let href = link.getAttribute('href') || '';
        if (!href) return;
        
        // 構建完整 URL 用於去重
        if (!href.startsWith('http')) {
          if (href.startsWith('/')) {
            // 絕對路徑，直接加上域名
            href = `https://500.gov.tw${href}`;
          } else if (href.startsWith('?')) {
            // 以 ? 開頭，是查詢參數
            href = `https://500.gov.tw/FOAS/actions/Vendor114.action${href}`;
          } else if (href.includes('Vendor114.action')) {
            // 如果已經包含 Vendor114.action，檢查是否需要加上基礎路徑
            if (href.startsWith('Vendor114.action')) {
              // 格式：Vendor114.action?productList&seqno=...
              href = `https://500.gov.tw/FOAS/actions/${href}`;
            } else {
              // 格式：/FOAS/actions/Vendor114.action?...
              href = `https://500.gov.tw${href.startsWith('/') ? '' : '/'}${href}`;
            }
          } else if (href.includes('productList') && href.includes('seqno')) {
            // 如果包含查詢參數關鍵字，構建完整 URL
            href = `https://500.gov.tw/FOAS/actions/Vendor114.action?${href}`;
          } else {
            // 其他情況，嘗試加上完整路徑
            href = `https://500.gov.tw/FOAS/actions/Vendor114.action?${href}`;
          }
        }
        
        // 如果已經處理過這個 URL，跳過
        if (seenUrls.has(href)) {
          return;
        }
        seenUrls.add(href);
        
        // 收集連結信息
        const linkInfo = {
          index: index + 1,
          href: href,
          linkText: link.textContent.trim(),
          originalHref: link.getAttribute('href') || '',
        };
        
        // 直接從連結文字提取店名
        const linkText = link.textContent.trim();
        const extractedName = cleanVendorName(linkText);
        
        linkInfo.extractedName = extractedName;
        linkInfo.linkText = linkText;
        
        // 檢查是否為目標店家
        const matchingTargetName = findMatchingTargetName(extractedName);
        if (!matchingTargetName) {
          linkInfo.added = false;
          linkInfo.reason = '不在目標列表中';
          allLinksInfo.push(linkInfo);
          return;
        }
        
        // 使用匹配的目標店名（標準化）
        const data = {
          name: matchingTargetName, // 使用目標列表中的標準名稱
          address: '', // 地址將從 vendors.csv 讀取或從詳情頁提取
          detailUrl: href,
        };
        
        linkInfo.isTargetVendor = true;
        linkInfo.matchingTargetName = matchingTargetName;
        
        // 只要有店名就添加（地址稍後從 vendors.csv 或詳情頁獲取）
        if (data.name) {
          vendors.push(data);
          linkInfo.added = true;
          linkInfo.reason = '成功提取（目標店家）';
        } else {
          linkInfo.added = false;
          linkInfo.reason = '未提取到店名';
        }
        
        allLinksInfo.push(linkInfo);
      });
      
      // 如果方法1沒有找到足夠的店家，使用備用方法
      if (vendors.length === 0) {
        const containers = Array.from(document.querySelectorAll('tr, div, li'));
        containers.forEach((container) => {
          const text = container.textContent || '';
          if (!text.includes('營業地址') || !text.includes('臺北市')) {
            return;
          }
          
          // 檢查是否已經處理過（通過檢查是否有詳情頁連結）
          const existingLink = container.querySelector('a[href*="seqno"][href*="productList"]');
          if (!existingLink) return;
          
          let href = existingLink.getAttribute('href') || '';
          if (!href) return;
          
          // 構建完整 URL
          if (!href.startsWith('http')) {
              if (href.startsWith('/')) {
                // 絕對路徑，直接加上域名
                href = `https://500.gov.tw${href}`;
            } else if (href.startsWith('?')) {
              // 以 ? 開頭，是查詢參數
              href = `https://500.gov.tw/FOAS/actions/Vendor114.action${href}`;
              } else if (href.includes('Vendor114.action')) {
              // 如果已經包含 Vendor114.action，檢查是否需要加上基礎路徑
              if (href.startsWith('Vendor114.action')) {
                // 格式：Vendor114.action?productList&seqno=...
                href = `https://500.gov.tw/FOAS/actions/${href}`;
              } else {
                // 格式：/FOAS/actions/Vendor114.action?...
                href = `https://500.gov.tw${href.startsWith('/') ? '' : '/'}${href}`;
              }
              } else if (href.includes('productList') && href.includes('seqno')) {
                // 如果包含查詢參數關鍵字，構建完整 URL
                href = `https://500.gov.tw/FOAS/actions/Vendor114.action?${href}`;
              } else {
                // 其他情況，嘗試加上完整路徑
              href = `https://500.gov.tw/FOAS/actions/Vendor114.action?${href}`;
            }
          }
          
          if (seenUrls.has(href)) return;
          seenUrls.add(href);
          
          const data = {
            name: '',
            address: '',
            detailUrl: href,
          };
          
          // 提取店名和地址（使用相同的邏輯）
          const lines = text.split('\n').map(line => line.trim()).filter(line => line.length > 0);
          for (const line of lines) {
            if (line && 
                !line.includes('營業地址') && 
                !line.includes('營業電話') && 
                !line.includes('營業時間') &&
                !line.includes('網址') &&
                line.length < 200 &&
                line.length > 1 &&
                !/^\d{3}\s*臺北市/.test(line)) {
              data.name = line;
              break;
            }
          }
          
          const addressMatch = text.match(/營業地址[：:]\s*(\d{3}\s*臺北市[^\n\r]+?)(?:\s*營業地址連結|$)/);
          if (addressMatch && addressMatch[1]) {
            let address = addressMatch[1].trim();
            address = address.replace(/\s*營業地址連結.*$/, '');
            address = address.replace(/\s*連結.*$/, '');
            address = address.replace(/\s*https?:\/\/[^\s]+/gi, '');
            data.address = address.trim();
          }
          
        if (data.name && data.address && data.address.includes('臺北市')) {
          vendors.push(data);
        }
      });
      }
      
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
        linkCount: linkCount,
        processedLinks: detailLinks.length,
        allLinksInfo: allLinksInfo, // 調試信息
      };
    }, targetVendorNames);
    
    let vendorsList = vendorBasicInfo.vendors || vendorBasicInfo;
    
    // 按照目標列表的順序排序
    vendorsList.sort((a, b) => {
      const indexA = targetVendorNames.findIndex(name => 
        name.includes(a.name) || a.name.includes(name)
      );
      const indexB = targetVendorNames.findIndex(name => 
        name.includes(b.name) || b.name.includes(name)
      );
      if (indexA === -1 && indexB === -1) return 0;
      if (indexA === -1) return 1;
      if (indexB === -1) return -1;
      return indexA - indexB;
    });
    
    console.log(`\n找到 ${vendorBasicInfo.linkCount || 0} 個詳情頁連結`);
    console.log(`✓ 從列表頁提取到 ${vendorsList.length} 個目標店家基本資訊`);
    console.log(`目標店家總數: ${targetVendorNames.length}，找到: ${vendorsList.length}，缺失: ${targetVendorNames.length - vendorsList.length}\n`);
    
    // 如果找到的店家少於目標數量，顯示未找到的店家
    if (vendorsList.length < targetVendorNames.length) {
      const foundNames = new Set(vendorsList.map(v => v.name));
      const missingNames = targetVendorNames.filter(name => {
        // 檢查是否有匹配的店家
        for (const foundName of foundNames) {
          if (name.includes(foundName) || foundName.includes(name)) {
            return false;
          }
        }
        return true;
      });
      if (missingNames.length > 0 && missingNames.length <= 20) {
        console.log('未找到的店家（前20個）:');
        missingNames.slice(0, 20).forEach(name => console.log(`  - ${name}`));
        console.log('');
      }
    }
    
    // 顯示調試信息
    if (vendorBasicInfo.allLinksInfo && vendorBasicInfo.allLinksInfo.length > 0) {
      console.log('=== 連結和提取資料調試信息 ===');
      const successCount = vendorBasicInfo.allLinksInfo.filter(link => link.added).length;
      const failCount = vendorBasicInfo.allLinksInfo.length - successCount;
      console.log(`成功提取: ${successCount} 個，失敗: ${failCount} 個\n`);
      
      // 顯示前10個連結的詳細信息
      console.log('前 10 個連結的詳細信息:');
      vendorBasicInfo.allLinksInfo.slice(0, 10).forEach((linkInfo, idx) => {
        console.log(`\n[${linkInfo.index}] ${linkInfo.added ? '✓' : '✗'} ${linkInfo.reason || ''}`);
        console.log(`  連結: ${linkInfo.originalHref.substring(0, 80)}...`);
        console.log(`  連結文字: ${linkInfo.linkText || '(無)'}`);
        console.log(`  提取到的店名: ${linkInfo.extractedName || '(無)'}`);
        console.log(`  提取到的地址: ${linkInfo.extractedAddress || '(無)'}`);
        if (linkInfo.containerText) {
          console.log(`  容器文字預覽: ${linkInfo.containerText.substring(0, 100)}...`);
        }
      });
      
      // 如果失敗的連結較多，顯示失敗原因統計
      if (failCount > 0) {
        console.log('\n失敗原因統計:');
        const reasonCounts = {};
        vendorBasicInfo.allLinksInfo.forEach(link => {
          if (!link.added && link.reason) {
            reasonCounts[link.reason] = (reasonCounts[link.reason] || 0) + 1;
          }
        });
        Object.entries(reasonCounts).forEach(([reason, count]) => {
          console.log(`  ${reason}: ${count} 個`);
        });
      }
      
      console.log('\n=== 調試信息結束 ===\n');
    }
    
    // 如果提取到的店家數量遠少於連結數量，可能是提取邏輯有問題
    if (vendorBasicInfo.linkCount > 0 && vendorsList.length === 0) {
      console.log('⚠ 警告: 找到連結但未提取到店家資料，可能是提取邏輯有問題');
    }
    
    // 從 vendors.csv 讀取的地址對應關係中填充地址
    console.log('從 vendors.csv 填充地址資訊...');
    for (const vendor of vendorsList) {
      if (!vendor.address && vendor.name) {
        const address = vendorAddressMap.get(vendor.name);
        if (address) {
          vendor.address = address;
        }
      }
    }
    
    console.log(`開始進入詳情頁提取完整資料...\n`);
    
    const vendors = [];
    const startIndex = 357; // 第358家（索引從0開始，所以是357）
    
    // 檢查列表長度
    if (vendorsList.length <= startIndex) {
      console.log(`⚠ 警告: 列表只有 ${vendorsList.length} 家，不足第 358 家，無法爬取`);
      console.log(`總共爬取 0 個店家`);
      return;
    }
    
    const endIndex = Math.min(377, vendorsList.length - 1); // 第378家或列表末尾
    const totalToScrape = endIndex - startIndex + 1;
    console.log(`將爬取第 ${startIndex + 1} 家到第 ${endIndex + 1} 家（共 ${totalToScrape} 家）\n`);
    
    const seenNames = new Set(); // 用於檢測重複
    
    // 逐個進入詳情頁提取完整資料（從第358家開始）
    for (let i = startIndex; i <= endIndex; i++) {
      const basicInfo = vendorsList[i];
      const actualIndex = i + 1; // 實際編號（從1開始）
      const progress = `[${actualIndex}/${vendorsList.length}]`;
      console.log(`${progress} 正在爬取: "${basicInfo.name}"`);
      
      // 檢查是否重複
      if (seenNames.has(basicInfo.name)) {
        console.log(`  ⚠ 檢測到重複店家: "${basicInfo.name}"，停止爬取`);
        break;
      }
      seenNames.add(basicInfo.name);
      
      // 驗證基本資料
      if (!basicInfo.name) {
        console.log(`  ⚠ 跳過資料不完整: 無店名`);
        continue;
      }
      
      // 如果沒有地址，嘗試從 vendors.csv 讀取
      if (!basicInfo.address) {
        const address = vendorAddressMap.get(basicInfo.name);
        if (address) {
          basicInfo.address = address;
        } else {
          console.log(`  ⚠ 警告: 未找到地址，將從詳情頁提取`);
        }
      }
      
      // 如果地址存在，確保包含臺北市
      if (basicInfo.address && !basicInfo.address.includes('臺北市')) {
        console.log(`  ⚠ 警告: 地址不包含臺北市: ${basicInfo.address}`);
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
                // 提取地址，排除「營業地址連結」和網址等文字
                const addressMatch = addressText.match(/營業地址[：:]\s*(\d{3}\s*臺北市[^\n\r]+?)(?:\s*營業地址連結|$)/);
                if (addressMatch && addressMatch[1]) {
                  let address = addressMatch[1].trim();
                  // 清理地址，移除多餘的文字
                  address = address.replace(/\s*營業地址連結.*$/, '');
                  address = address.replace(/\s*連結.*$/, '');
                  // 移除網址（http:// 或 https:// 開頭的內容）
                  address = address.replace(/\s*https?:\/\/[^\s]+.*$/i, '');
                  // 移除 Google Maps 連結
                  address = address.replace(/\s*https?:\/\/.*google.*maps.*$/i, '');
                  // 確保地址不包含任何 URL
                  address = address.replace(/\s*https?:\/\/[^\s]+/gi, '');
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
              
              // 輔助函數：檢查是否為有效的商家網站連結（排除地圖、社交媒體等）
              const isValidWebsite = (href) => {
                if (!href) return false;
                // 排除的域名和服務
                const excludedDomains = [
                  '500.gov.tw',
                  'mailto:',
                  'facebook.com',
                  'fb.com',
                  'line.me',
                  'google.com.tw/maps',
                  'maps.google.com',
                  'maps.google.com.tw',
                  'google.com/maps',
                  'goo.gl/maps',
                  'maps.app.goo.gl',
                ];
                // 檢查是否包含排除的域名
                for (const domain of excludedDomains) {
                  if (href.includes(domain)) {
                    return false;
                  }
                }
                // 必須是 http 或 https 開頭
                if (!href.startsWith('http://') && !href.startsWith('https://')) {
                  return false;
                }
                return true;
              };
              
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
                  if (isValidWebsite(href)) {
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
                      if (isValidWebsite(href)) {
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
                      if (isValidWebsite(href)) {
                        data.website = href;
                      }
                    }
                  }
                }
              }
              
              // 方法2: 如果方法1沒找到，尋找所有外部連結（排除地圖、社交媒體等）
              if (!data.website) {
                const websiteLinks = Array.from(document.querySelectorAll('a[href^="http"]'));
                // 優先選擇看起來像官網的連結（包含常見域名，且不是地圖連結）
                for (const link of websiteLinks) {
                  const href = link.getAttribute('href') || '';
                  if (isValidWebsite(href)) {
                    // 優先選擇包含常見頂級域名的連結
                    if (href.match(/\.(com|tw|org|net|edu|gov|co|io|app)(\/|$)/i)) {
                      data.website = href;
                      break;
                    }
                  }
                }
                // 如果還是沒找到，使用第一個有效的外部連結（但排除地圖）
                if (!data.website) {
                  for (const link of websiteLinks) {
                    const href = link.getAttribute('href') || '';
                    if (isValidWebsite(href)) {
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
      const currentCount = i - startIndex + 1; // 當前爬取的數量（從1開始）
      const totalCount = endIndex - startIndex + 1; // 總共要爬取的數量
      if (currentCount % 10 === 0 || i === endIndex) {
        const percentage = Math.round((currentCount / totalCount) * 100);
        console.log(`\n進度: ${percentage}% (${currentCount}/${totalCount}, 第 ${actualIndex} 家)\n`);
      }
    }

    console.log(`\n總共爬取 ${vendors.length} 個店家（第 ${startIndex + 1} 家到第 ${startIndex + vendors.length} 家）`);
    console.log('正在寫入 CSV 檔案...');

    // 寫入 CSV
    await csvWriter.writeRecords(vendors);
    console.log(`\n✓ CSV 檔案已生成: vendors_5.csv`);
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

