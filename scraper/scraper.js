const puppeteer = require('puppeteer');
const createCsvWriter = require('csv-writer').createObjectCsvWriter;

const BASE_URL = 'https://500.gov.tw/FOAS/actions/Vendor114.action?view';

// 輔助函數：替代已移除的 waitForTimeout
function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// CSV 寫入器設定
const csvWriter = createCsvWriter({
  path: 'vendors.csv',
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
    
    console.log('\n開始提取店家列表...');
    
    // 提取當前頁面的店家列表
    const vendorLinks = await page.evaluate(() => {
        const links = [];
        
        // 方法1: 尋找包含 seqno 和 productList 的連結（詳情頁連結）
        const detailLinks = document.querySelectorAll('a[href*="seqno"]');
        detailLinks.forEach(el => {
          const href = el.getAttribute('href');
          // 檢查是否包含 productList（詳情頁連結）
          if (href && href.includes('seqno') && href.includes('productList')) {
            // 修復 URL：確保有正確的斜線
            let fullHref = href;
            if (!href.startsWith('http')) {
              // 如果 href 以 / 開頭，直接拼接；否則需要加上 /
              if (href.startsWith('/')) {
                fullHref = `https://500.gov.tw${href}`;
              } else {
                fullHref = `https://500.gov.tw/${href}`;
              }
            }
            
            // 嘗試從連結文字或父元素獲取店名
            let name = el.textContent.trim();
            
            // 如果連結文字太長或為空，從父元素獲取
            if (!name || name.length > 100 || name.includes('營業地址')) {
              const parent = el.closest('tr, div, li, td');
              if (parent) {
                const parentText = parent.textContent.trim();
                // 提取第一行作為店名（排除「營業地址」等）
                const lines = parentText.split('\n').filter(line => {
                  const trimmed = line.trim();
                  return trimmed && 
                         !trimmed.includes('營業地址') && 
                         !trimmed.includes('地址') &&
                         trimmed.length < 100;
                });
                if (lines.length > 0) {
                  name = lines[0].trim();
                }
              }
            }
            
            // 如果還是沒有名字，嘗試從整個列表項提取
            if (!name || name.length > 100) {
              const listItem = el.closest('tr, div, li');
              if (listItem) {
                const allText = listItem.textContent;
                const match = allText.match(/^([^\n\r]+)/);
                if (match && match[1]) {
                  name = match[1].trim();
                }
              }
            }
            
            if (name && name.length < 150 && !name.includes('營業地址')) {
              links.push({ href: fullHref, name: name });
            }
          }
        });

        // 方法2: 如果方法1沒找到，嘗試從所有包含 seqno 的連結提取
        if (links.length === 0) {
          const allSeqnoLinks = document.querySelectorAll('a[href*="seqno"]');
          allSeqnoLinks.forEach(el => {
            const href = el.getAttribute('href');
            if (href && href.includes('seqno')) {
              // 修復 URL：確保有正確的斜線
              let fullHref = href;
              if (!href.startsWith('http')) {
                if (href.startsWith('/')) {
                  fullHref = `https://500.gov.tw${href}`;
                } else {
                  fullHref = `https://500.gov.tw/${href}`;
                }
              }
              const parent = el.closest('tr, div, li');
              if (parent) {
                const text = parent.textContent.trim();
                const lines = text.split('\n').filter(line => {
                  const trimmed = line.trim();
                  return trimmed && 
                         !trimmed.includes('營業地址') && 
                         trimmed.length < 150;
                });
                if (lines.length > 0) {
                  const name = lines[0].trim();
                  if (name && name.length > 0) {
                    links.push({ href: fullHref, name: name });
                  }
                }
              }
            }
          });
        }

        // 去重並返回
        const uniqueLinks = [];
        const seenHrefs = new Set();
        for (const link of links) {
          if (!seenHrefs.has(link.href)) {
            seenHrefs.add(link.href);
            uniqueLinks.push(link);
          }
        }
        return uniqueLinks;
      });

    console.log(`✓ 找到 ${vendorLinks.length} 個店家`);
    
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
      console.log(`⚠ 注意: 發現有下一頁，但目前只爬取第一頁的 ${vendorLinks.length} 個店家`);
      console.log(`   如需爬取所有頁面，請告訴我`);
    }
    
    console.log(`\n開始爬取店家詳細資料...\n`);

    // 逐個進入店家詳情頁提取資料
    for (let i = 0; i < vendorLinks.length; i++) {
      const link = vendorLinks[i];
      const progress = `[${i + 1}/${vendorLinks.length}]`;
      console.log(`${progress} 正在爬取: "${link.name}"`);

        try {
          // 開啟新分頁訪問店家詳情
          const detailPage = await browser.newPage();
          
          // 確保 URL 格式正確
          let detailUrl = link.href;
          if (!detailUrl.startsWith('http')) {
            if (detailUrl.startsWith('/')) {
              detailUrl = `https://500.gov.tw${detailUrl}`;
            } else {
              detailUrl = `https://500.gov.tw/${detailUrl}`;
            }
          }
          
          console.log(`  訪問: ${detailUrl.substring(0, 80)}...`);
          await detailPage.goto(detailUrl, { waitUntil: 'networkidle2', timeout: 30000 });
          await delay(2000);

          // 提取店家詳細資訊
          const vendorData = await detailPage.evaluate(() => {
            const data = {
              name: '',
              address: '',
              phone: '',
              businessHours: '',
              website: '',
              description: '',
              category: '',
            };

            // 檢查是否是錯誤頁面（包含「回動滋網」或「目前領券很踴躍」）
            const pageText = document.body.textContent || '';
            if (pageText.includes('回動滋網') || pageText.includes('目前領券很踴躍')) {
              return data; // 返回空資料，表示這是錯誤頁面
            }

            // 提取店名 - 根據截圖，店名在詳情頁的標題位置
            // 先嘗試找包含「店名」標籤的元素
            const nameLabel = Array.from(document.querySelectorAll('*')).find(el => {
              const text = el.textContent || '';
              return text.includes('店名') && text.length < 50;
            });
            
            if (nameLabel) {
              const nameElement = nameLabel.nextElementSibling || nameLabel.parentElement;
              if (nameElement && nameElement.textContent.trim()) {
                data.name = nameElement.textContent.trim();
              }
            }
            
            // 如果還沒找到，嘗試其他選擇器
            if (!data.name) {
              const nameSelectors = [
                'h1', 'h2', 'h3',
                '[class*="name"]',
                '[class*="title"]',
                '[class*="vendor"]',
              ];
              for (const selector of nameSelectors) {
                try {
                  const el = document.querySelector(selector);
                  if (el && el.textContent.trim()) {
                    const text = el.textContent.trim();
                    // 排除明顯不是店名的文字
                    if (text.length > 0 && 
                        text.length < 150 && 
                        !text.includes('教育部') && 
                        !text.includes('體育署') &&
                        !text.includes('回動滋網') &&
                        !text.includes('單位簡介')) {
                      data.name = text;
                      break;
                    }
                  }
                } catch (e) {}
              }
            }

            // 提取地址 - 尋找包含「營業地址：」的文字
            const allElements = Array.from(document.querySelectorAll('*'));
            for (const el of allElements) {
              const text = el.textContent || '';
              if (text.includes('營業地址')) {
                // 嘗試提取地址（格式：營業地址：114 臺北市內湖區文德路108號B1）
                const match = text.match(/營業地址[：:]\s*([^\n\r]+)/);
                if (match && match[1]) {
                  const addr = match[1].trim();
                  // 確保地址包含臺北市
                  if (addr.includes('臺北市')) {
                    data.address = addr;
                    break;
                  }
                }
                // 如果沒有匹配，嘗試從下一個兄弟節點獲取
                const nextSibling = el.nextElementSibling;
                if (nextSibling) {
                  const addr = nextSibling.textContent.trim();
                  if (addr && addr.includes('臺北市')) {
                    data.address = addr;
                    break;
                  }
                }
                // 嘗試從父元素的下一個兄弟節點獲取
                const parent = el.parentElement;
                if (parent && parent.nextElementSibling) {
                  const addr = parent.nextElementSibling.textContent.trim();
                  if (addr && addr.includes('臺北市') && addr.length < 200) {
                    data.address = addr;
                    break;
                  }
                }
              }
            }

            // 提取電話 - 尋找包含「營業電話：」的文字
            for (const el of allElements) {
              const text = el.textContent || '';
              if (text.includes('營業電話')) {
                const match = text.match(/營業電話[：:]\s*([^\n\r]+)/);
                if (match && match[1]) {
                  data.phone = match[1].trim();
                  break;
                }
                const nextSibling = el.nextElementSibling;
                if (nextSibling && nextSibling.textContent.trim()) {
                  data.phone = nextSibling.textContent.trim();
                  break;
                }
              }
            }

            // 提取營業時間 - 尋找包含「營業時間：」的文字
            for (const el of allElements) {
              const text = el.textContent || '';
              if (text.includes('營業時間')) {
                const match = text.match(/營業時間[：:]\s*([^\n\r]+)/);
                if (match && match[1]) {
                  data.businessHours = match[1].trim();
                  break;
                }
                const nextSibling = el.nextElementSibling;
                if (nextSibling && nextSibling.textContent.trim()) {
                  data.businessHours = nextSibling.textContent.trim();
                  break;
                }
              }
            }

            // 提取網址 - 尋找外部連結
            const websiteLinks = Array.from(document.querySelectorAll('a[href^="http"]'));
            for (const link of websiteLinks) {
              const href = link.getAttribute('href') || '';
              if (href && !href.includes('500.gov.tw') && !href.includes('mailto:')) {
                data.website = href;
                break;
              }
            }

            // 提取類別 - 尋找包含「類別：」或「運動場館-」的文字
            for (const el of allElements) {
              const text = el.textContent || '';
              if (text.includes('類別') || text.includes('運動場館')) {
                const categoryMatch = text.match(/類別[：:]\s*([^\n\r]+)|運動場館[-\-]([^\n\r]+)/);
                if (categoryMatch) {
                  data.category = (categoryMatch[1] || categoryMatch[2] || '').trim();
                  break;
                }
              }
            }

            // 提取描述 - 尋找簡短的描述文字（例如「練一下健身房,分鐘計費,無須綁約」）
            const descCandidates = Array.from(document.querySelectorAll('p, div, span'));
            for (const el of descCandidates) {
              const text = el.textContent.trim();
              // 描述通常是較短的文字，不包含標籤性的詞彙
              if (text.length > 10 && text.length < 200 && 
                  !text.includes('營業') && !text.includes('地址') && 
                  !text.includes('電話') && !text.includes('時間') &&
                  !text.includes('類別') && !text.includes('網址')) {
                // 檢查是否包含逗號或常見的描述性詞彙
                if (text.includes('，') || text.includes(',') || 
                    text.includes('計費') || text.includes('綁約') || 
                    text.includes('健身房') || text.includes('運動')) {
                  data.description = text;
                  break;
                }
              }
            }

            return data;
          });

          // 檢查是否是錯誤頁面
          if (!vendorData.name || vendorData.name.includes('教育部') || vendorData.name.includes('體育署')) {
            console.log(`  ⚠ 跳過錯誤頁面或無效資料: ${link.name}`);
            await detailPage.close();
            await delay(500);
            continue;
          }

          // 如果店名為空，使用連結中的名稱（但要去除重複）
          if (!vendorData.name || vendorData.name.trim() === '') {
            // 清理連結中的名稱（去除重複）
            let cleanName = link.name;
            // 如果名稱重複（例如 "WellSpace 唯爾運動WellSpace 唯爾運動"）
            const nameLength = cleanName.length;
            if (nameLength > 0) {
              const halfLength = Math.floor(nameLength / 2);
              const firstHalf = cleanName.substring(0, halfLength);
              const secondHalf = cleanName.substring(halfLength);
              if (firstHalf === secondHalf) {
                cleanName = firstHalf;
              }
            }
            vendorData.name = cleanName;
          }

          // 過濾：只保留台北市的店家（雙重檢查，確保資料正確）
          if (!vendorData.address || !vendorData.address.includes('臺北市')) {
            console.log(`  ⚠ 跳過非台北市店家: ${vendorData.name} (${vendorData.address || '無地址'})`);
            await detailPage.close();
            await delay(500);
            continue;
          }
          
          // 額外檢查：確保地址格式正確（應該包含郵遞區號和「臺北市」）
          const addressPattern = /\d{3}\s*臺北市/;
          if (!addressPattern.test(vendorData.address)) {
            console.log(`  ⚠ 地址格式異常，跳過: ${vendorData.name} (${vendorData.address})`);
            await detailPage.close();
            await delay(500);
            continue;
          }

          vendors.push(vendorData);
          console.log(`  ✓ 成功提取: ${vendorData.name}`);
          if (vendorData.address) console.log(`    地址: ${vendorData.address}`);
          if (vendorData.phone) console.log(`    電話: ${vendorData.phone}`);
          if (vendorData.category) console.log(`    類別: ${vendorData.category}`);

          await detailPage.close();
          await delay(1000); // 避免請求過快

        } catch (error) {
          console.error(`  ✗ 錯誤: ${link.name} - ${error.message}`);
        }
        
        // 顯示進度百分比
        const percentage = Math.round(((i + 1) / vendorLinks.length) * 100);
        if ((i + 1) % 10 === 0 || i === vendorLinks.length - 1) {
          console.log(`\n進度: ${percentage}% (${i + 1}/${vendorLinks.length})\n`);
        }
      }

    console.log(`\n總共爬取 ${vendors.length} 個店家`);
    console.log('正在寫入 CSV 檔案...');

    // 寫入 CSV
    await csvWriter.writeRecords(vendors);
    console.log('✓ CSV 檔案已生成: vendors.csv');

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

