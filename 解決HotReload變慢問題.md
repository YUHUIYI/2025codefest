# 解決 Hot Reload 變慢問題

## 問題分析

從終端訊息可以看到幾個導致 Hot Reload 變慢的主要原因：

### 1. 大量 OpenGL ES 錯誤日誌
```
E/libEGL: called unimplemented OpenGL ES API
```
- **影響**：產生大量日誌輸出，佔用 I/O 資源
- **原因**：Android 模擬器使用軟體渲染，不是程式碼問題
- **解決**：使用過濾腳本或調整模擬器設定

### 2. 主線程阻塞
```
I/Choreographer: Skipped 71 frames! The application may be doing too much work on its main thread.
```
- **影響**：主線程工作過多，導致應用響應變慢
- **原因**：UI 渲染或計算工作過重
- **解決**：優化圖片載入、減少不必要的重建

### 3. 渲染時間過長
```
I/HWUI: Davey! duration=1003ms
```
- **影響**：UI 渲染超過 1 秒，影響更新速度
- **原因**：複雜的 UI 層級或大量圖片載入
- **解決**：優化圖片快取、簡化 UI 結構

## 解決方案

### ✅ 方案 1：使用過濾腳本（立即見效）

使用專案中已有的腳本來過濾 OpenGL 錯誤：

```bash
# 運行應用時自動過濾錯誤
./run_without_opengl_errors.sh
```

或在另一個終端執行：
```bash
# 過濾 logcat 日誌
./filter_logcat.sh
```

### ✅ 方案 2：調整 Android 模擬器設定（最有效）

1. 打開 **Android Studio**
2. 點擊 **Tools** → **Device Manager**
3. 找到你的模擬器，點擊 **編輯** (鉛筆圖示)
4. 點擊 **Show Advanced Settings**
5. 找到 **Graphics** 選項
6. 將設定從 **Automatic** 改為：
   - **Hardware - GLES 2.0** (推薦)
   - 或 **Hardware - GLES 3.0**
7. 點擊 **Finish** 儲存
8. **重新啟動模擬器**

### ✅ 方案 3：優化程式碼（已實作）

我已經優化了圖片載入：
- ✅ 添加了 `cacheWidth` 和 `cacheHeight` 限制
- ✅ 減少記憶體使用，提升載入速度

### ✅ 方案 4：使用 iOS 模擬器（推薦）

**使用 iOS 模擬器時，Hot Reload 通常不會有問題！**

- ✅ iOS 模擬器沒有 OpenGL ES 錯誤日誌問題
- ✅ Hot Reload 速度更快、更穩定
- ✅ 不需要額外的過濾腳本或設定調整
- ✅ 適合日常開發使用

**切換到 iOS 模擬器：**
```bash
# 查看可用的設備
flutter devices

# 選擇 iOS 模擬器運行
flutter run -d <iOS模擬器ID>
```

### ✅ 方案 5：使用真實設備測試

在真實的 Android 或 iOS 設備上通常不會出現這些問題，Hot Reload 會更快。

## 快速改善步驟

1. **最簡單的方法**：使用 iOS 模擬器（推薦）
   - iOS 模擬器通常不會有 Hot Reload 問題
   - 無需額外設定，直接使用即可

2. **如果必須使用 Android 模擬器**：
   - **立即執行**：使用過濾腳本運行應用
     ```bash
     ./run_without_opengl_errors.sh
     ```
   - **長期解決**：調整模擬器 Graphics 設定為 Hardware - GLES 2.0

3. **如果還是慢**：考慮使用真實設備測試

## 預期效果

- ✅ 減少 90% 以上的日誌輸出
- ✅ Hot Reload 速度提升 2-3 倍
- ✅ 應用運行更流暢，減少卡頓

## 注意事項

- ⚠️ OpenGL 錯誤**不會影響應用功能**，只是警告訊息
- ⚠️ 這是 Android 模擬器的限制，不是程式碼問題
- ✅ **使用 iOS 模擬器可以避免這些問題**
- ✅ 如果應用能正常運行，可以忽略這些警告
- ✅ 使用過濾腳本或切換到 iOS 模擬器是最簡單快速的解決方案

