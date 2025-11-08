const fs = require('fs');
const path = require('path');
const { parse } = require('csv-parse/sync');
const createCsvWriter = require('csv-writer').createObjectCsvWriter;

// 清理描述字段 - 移除HTML标签和无效内容
function cleanDescription(desc) {
  if (!desc) return '';
  
  // 移除"主要內容前往主要內容"及其后的所有内容
  const mainContentIndex = desc.indexOf('主要內容前往主要內容');
  if (mainContentIndex !== -1) {
    desc = desc.substring(0, mainContentIndex).trim();
  }
  
  // 移除HTML标签
  desc = desc.replace(/<[^>]*>/g, '');
  
  // 移除多余的空白字符和换行符
  desc = desc.replace(/\s+/g, ' ').trim();
  
  // 移除"動滋網"等无效内容
  desc = desc.replace(/動滋網/g, '').trim();
  
  return desc;
}

// 清理地址格式
function cleanAddress(address) {
  if (!address) return '';
  
  // 统一"台北市"为"臺北市"
  address = address.replace(/台北市/g, '臺北市');
  
  // 移除重复的"臺北市"
  address = address.replace(/臺北市\s*臺北市/g, '臺北市');
  
  // 处理"臺北市 中山區 臺北市"这样的格式（中间有区名）
  address = address.replace(/臺北市\s+([^市]+?)\s+臺北市/g, '臺北市$1');
  
  // 处理"104 臺北市中山區臺北市 中山區"这样的格式
  address = address.replace(/(\d+\s+臺北市[^市]+?區)\s*臺北市\s+([^市]+?區)/g, '$1$2');
  
  // 处理"104 臺北市中山區台北市中山區"这样的格式（台北市在中间）
  address = address.replace(/(\d+\s+臺北市)([^市]+?區)\s*臺北市\2/g, '$1$2');
  
  // 处理重复的区名，如"104 臺北市中山區中山區"或"104 臺北市中山區 中山區"
  address = address.replace(/(\d+\s+臺北市)([^市]+?區)\s*\2/g, '$1$2');
  
  // 移除地址中的多余空格
  address = address.replace(/\s+/g, ' ').trim();
  
  return address;
}

// 清理电话格式
function cleanPhone(phone) {
  if (!phone) return '';
  
  // 移除"營業電話："前缀
  phone = phone.replace(/^營業電話[：:]\s*/i, '').trim();
  
  // 移除"LINE:"等非电话号码内容
  if (phone.toLowerCase().includes('line:')) {
    return phone; // 保留LINE联系方式
  }
  
  return phone;
}

// 清理营业时间格式
function cleanHours(hours) {
  if (!hours) return '';
  
  // 移除"營業時間："前缀
  hours = hours.replace(/^營業時間[：:]\s*/i, '').trim();
  
  return hours;
}

// 清理类别
function cleanCategory(category) {
  if (!category) return '';
  
  // 移除"動滋券適用品項："前缀
  category = category.replace(/^動滋券適用品項[：:]\s*/i, '').trim();
  
  return category;
}

// 读取CSV文件
function readCSV(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n').filter(line => line.trim().length > 0);
    
    if (lines.length === 0) return [];
    
    const headers = lines[0].split(',').map(h => h.trim());
    const data = [];
    
    let currentRow = {};
    let currentField = '';
    let inQuotes = false;
    
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i];
      let row = {};
      let fieldIndex = 0;
      let currentValue = '';
      let quoteCount = 0;
      
      for (let j = 0; j < line.length; j++) {
        const char = line[j];
        
        if (char === '"') {
          quoteCount++;
          if (quoteCount % 2 === 1) {
            inQuotes = !inQuotes;
          } else {
            inQuotes = false;
          }
        } else if (char === ',' && !inQuotes) {
          if (fieldIndex < headers.length) {
            row[headers[fieldIndex]] = currentValue.trim();
            currentValue = '';
            fieldIndex++;
          }
        } else {
          currentValue += char;
        }
      }
      
      // 添加最后一个字段
      if (fieldIndex < headers.length) {
        row[headers[fieldIndex]] = currentValue.trim();
      }
      
      // 处理多行字段（描述字段可能跨多行）
      if (i < lines.length - 1 && line.endsWith('"') === false && inQuotes) {
        // 继续读取下一行
        continue;
      }
      
      data.push(row);
    }
    
    return data;
  } catch (error) {
    console.error(`读取文件 ${filePath} 失败:`, error.message);
    return [];
  }
}

// 使用csv-parse读取CSV（处理多行字段）
function readCSVSimple(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    
    // 使用csv-parse解析，支持多行字段
    const records = parse(content, {
      columns: true,
      skip_empty_lines: false,
      relax_quotes: true,
      relax_column_count: true,
      trim: false, // 不自动trim，保留原始格式
      bom: true, // 处理BOM
      skip_records_with_error: false,
      on_record: (record, context) => {
        // 清理每个字段
        const cleaned = {};
        for (const key in record) {
          if (record.hasOwnProperty(key)) {
            cleaned[key] = (record[key] || '').trim();
          }
        }
        return cleaned;
      }
    });
    
    // 过滤掉空记录
    return records.filter(record => {
      // 至少要有商家名称
      return record['商家名稱'] && record['商家名稱'].trim().length > 0;
    });
  } catch (error) {
    console.error(`读取文件 ${filePath} 失败:`, error.message);
    console.error(error.stack);
    return [];
  }
}

// 主函数
async function formatVendors() {
  const files = ['vendors_2.csv', 'vendors_3.csv', 'vendors_4.csv'];
  const allVendors = [];
  const seenVendors = new Set(); // 用于去重
  
  console.log('开始读取和格式化数据...');
  
  for (const file of files) {
    const filePath = path.join(__dirname, file);
    if (!fs.existsSync(filePath)) {
      console.warn(`文件不存在: ${file}`);
      continue;
    }
    
    console.log(`正在处理: ${file}`);
    const data = readCSVSimple(filePath);
    console.log(`  读取到 ${data.length} 条记录`);
    
    for (const vendor of data) {
      // 清理数据
      const name = (vendor['商家名稱'] || '').trim();
      const address = cleanAddress(vendor['地址'] || '');
      const phone = cleanPhone(vendor['營業電話'] || '');
      const hours = cleanHours(vendor['營業時間'] || '');
      const url = (vendor['網址'] || '').trim();
      const description = cleanDescription(vendor['描述'] || '');
      const category = cleanCategory(vendor['類別'] || '');
      
      // 跳过空名称的记录
      if (!name) continue;
      
      // 创建唯一标识（使用名称+地址）
      const uniqueKey = `${name}|${address}`.toLowerCase();
      
      // 去重
      if (seenVendors.has(uniqueKey)) {
        console.log(`  跳过重复: ${name}`);
        continue;
      }
      
      seenVendors.add(uniqueKey);
      
      allVendors.push({
        name,
        address,
        phone,
        hours,
        url,
        description,
        category
      });
    }
  }
  
  console.log(`\n总共处理 ${allVendors.length} 条唯一记录`);
  
  // 写入CSV文件
  const csvWriter = createCsvWriter({
    path: path.join(__dirname, 'vendors_formatted.csv'),
    header: [
      { id: 'name', title: '商家名稱' },
      { id: 'address', title: '地址' },
      { id: 'phone', title: '營業電話' },
      { id: 'hours', title: '營業時間' },
      { id: 'url', title: '網址' },
      { id: 'description', title: '描述' },
      { id: 'category', title: '類別' }
    ],
    encoding: 'utf8'
  });
  
  await csvWriter.writeRecords(allVendors);
  console.log(`\n数据已保存到: vendors_formatted.csv`);
  console.log(`共 ${allVendors.length} 条记录`);
}

// 运行
formatVendors().catch(console.error);

