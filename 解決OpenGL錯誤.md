# 解決 OpenGL ES 錯誤的完整指南

## 問題說明

`E/libEGL: called unimplemented OpenGL ES API` 這些錯誤通常出現在 Android 模擬器上，是因為模擬器使用軟體渲染而非硬體加速導致的。**這些錯誤不會影響應用程式的功能**，只是警告訊息。

## 解決方案

### 方案 1：使用過濾腳本（推薦 - 最簡單）

我已經為你創建了兩個腳本：

#### 1. 運行應用時自動過濾錯誤
```bash
./run_without_opengl_errors.sh
```

#### 2. 單獨過濾 logcat 日誌
```bash
./filter_logcat.sh
```

### 方案 2：修改 Android 模擬器設定（最有效）

1. 打開 **Android Studio**
2. 點擊 **Tools** → **Device Manager** (或 AVD Manager)
3. 找到你的模擬器，點擊 **編輯** (鉛筆圖示)
4. 點擊 **Show Advanced Settings**
5. 找到 **Graphics** 選項
6. 將設定從 **Automatic** 改為：
   - **Hardware - GLES 2.0** (推薦)
   - 或 **Hardware - GLES 3.0**
7. 點擊 **Finish** 儲存
8. 重新啟動模擬器

### 方案 3：使用 adb 命令過濾（手動）

在終端機執行：
```bash
# 只顯示 Flutter 相關日誌，過濾 OpenGL 錯誤
adb logcat | grep -v "E/libEGL.*called unimplemented OpenGL ES API"
```

或者只顯示重要日誌：
```bash
# 只顯示 Error 和 Warning（排除 OpenGL 錯誤）
adb logcat *:E *:W | grep -v "E/libEGL"
```

### 方案 4：使用真實設備測試

在真實的 Android 設備上通常不會出現這些警告。

### 方案 5：在 Android Studio 中過濾

1. 打開 **Logcat** 視窗
2. 在搜尋框輸入：`-libEGL` (負號表示排除)
3. 或使用正則表達式：`^(?!.*libEGL).*$`

## 已做的配置優化

我已經在專案中做了以下優化：

1. ✅ 在 `AndroidManifest.xml` 中添加了 OpenGL ES 版本聲明
2. ✅ 啟用了硬體加速 (`hardwareAccelerated="true"`)
3. ✅ 啟用了大堆記憶體 (`largeHeap="true"`)
4. ✅ 在 `gradle.properties` 中添加了渲染優化配置

## 重要提示

- ⚠️ 這些錯誤**不會影響應用程式功能**
- ⚠️ 這是模擬器的限制，不是你的程式碼問題
- ✅ 如果應用能正常運行，可以忽略這些警告
- ✅ 如果應用出現崩潰或功能異常，請檢查其他錯誤訊息

## 快速測試

執行以下命令測試應用是否正常運行：
```bash
flutter run
```

如果應用能正常啟動和運行，這些 OpenGL 錯誤可以安全地忽略。

