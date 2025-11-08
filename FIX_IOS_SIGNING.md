# 修复 iOS 签名问题

## 已完成的修复

✅ **Bundle Identifier 已更新**
- 从 `com.example.townpass` 改为 `com.townpass.app`
- Apple 不允许使用 `com.example` 作为 Bundle ID

✅ **自动签名已启用**
- Debug、Release、Profile 配置都已启用 `CODE_SIGN_STYLE = Automatic`

## 接下来需要做的：在 Xcode 中添加 Apple ID

### 步骤 1：打开 Xcode 项目

```bash
cd "/Users/chenpinxiang/Desktop/NTU裡的NT/課程學習/大三上/大黑克松/2025codefest"
open ios/Runner.xcworkspace
```

**重要**：必须打开 `.xcworkspace` 文件，不是 `.xcodeproj` 文件！

### 步骤 2：添加 Apple ID 账号

1. 在 Xcode 中，点击菜单栏的 **Xcode → Settings**（或按 `Cmd + ,`）
2. 切换到 **Accounts**（账号）标签
3. 点击左下角的 **+** 按钮
4. 选择 **Apple ID**
5. 输入你的 Apple ID 和密码（可以是免费的 Apple ID，不需要付费开发者账号）
6. 点击 **Sign In**

### 步骤 3：配置签名设置

1. 在 Xcode 左侧项目导航器中，选择 **Runner** 项目（最顶部的蓝色图标）
2. 在中间面板选择 **Runner** target（在 TARGETS 下）
3. 切换到 **Signing & Capabilities** 标签
4. 确保：
   - ✅ **Automatically manage signing** 已勾选
   - ✅ **Team** 下拉菜单中选择了你刚添加的 Apple ID
   - ✅ **Bundle Identifier** 显示为 `com.townpass.app`

### 步骤 4：验证配置

如果一切配置正确，你应该看到：
- ✅ **Signing Certificate** 显示为 "Apple Development: [你的名字]"
- ✅ **Provisioning Profile** 显示为 "Xcode Managed Profile"

### 步骤 5：运行应用

配置完成后，你可以：

**方式 A：使用 Flutter 命令**
```bash
cd "/Users/chenpinxiang/Desktop/NTU裡的NT/課程學習/大三上/大黑克松/2025codefest"
flutter run
```

**方式 B：在 Xcode 中运行**
1. 在 Xcode 顶部选择你的 iPhone 12 Pro Max 作为目标设备
2. 点击运行按钮（▶️）或按 `Cmd + R`

## 常见问题

### Q: 我没有付费的开发者账号，可以使用免费账号吗？
**A:** 可以！免费的 Apple ID 也可以用于在真实设备上运行应用，但有一些限制：
- 应用只能运行 7 天，之后需要重新安装
- 只能安装到你的设备上
- 某些功能可能受限

### Q: 如果出现 "No profiles for 'com.townpass.app' were found" 错误？
**A:** 
1. 确保在 Xcode 中选择了正确的 Team
2. 确保 **Automatically manage signing** 已勾选
3. 尝试清理并重新构建：
   ```bash
   flutter clean
   cd ios
   pod deintegrate
   pod install
   cd ..
   flutter run
   ```

### Q: 如果出现 "Signing for "Runner" requires a development team" 错误？
**A:** 
1. 确保在 Xcode 中添加了 Apple ID
2. 在 Signing & Capabilities 中选择该账号作为 Team
3. 如果 Team 下拉菜单是空的，点击 "Add Account..." 添加 Apple ID

### Q: 如何检查设备是否已连接？
**A:** 运行：
```bash
flutter devices
```
你应该能看到你的 iPhone 12 Pro Max。

## 提示

- 首次在真实设备上运行需要几分钟时间（编译和安装）
- 如果应用需要特殊权限（如定位、相机），首次运行时会提示授权
- 确保 iPhone 和 Mac 连接到同一个 Wi-Fi 网络（如果使用无线调试）

