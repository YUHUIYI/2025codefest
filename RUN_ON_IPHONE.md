# 在 iPhone 12 Pro Max 上运行 Flutter 应用

## 前置要求

1. ✅ Xcode 已安装（已确认：Xcode 26.1）
2. ✅ Flutter 环境已配置（已确认：Flutter 3.35.7）
3. ✅ 开发者账号已配置（已确认：开发团队 ZLLDAN62HX）

## 步骤

### 1. 连接并配对设备

1. 用 USB 线将 iPhone 12 Pro Max 连接到 Mac
2. 在 iPhone 上解锁，如果出现"信任此电脑"提示，选择"信任"
3. 打开 Xcode
4. 前往 **Window → Devices and Simulators**（或按 `Cmd + Shift + 2`）
5. 在左侧选择你的 iPhone 12 Pro Max
6. 如果显示"Use for Development"按钮，点击它
7. 按照提示完成配对（可能需要输入 iPhone 密码）

### 2. 验证设备连接

配对完成后，在终端运行：

```bash
cd "/Users/chenpinxiang/Desktop/NTU裡的NT/課程學習/大三上/大黑克松/2025codefest"
flutter devices
```

你应该能看到你的 iPhone 12 Pro Max 出现在设备列表中。

### 3. 运行应用

有两种方式运行：

#### 方式 A：使用 Flutter 命令（推荐）

```bash
cd "/Users/chenpinxiang/Desktop/NTU裡的NT/課程學習/大三上/大黑克松/2025codefest"
flutter run -d <你的设备ID>
```

或者直接指定设备名称：

```bash
flutter run -d "iPhone 12 Pro Max"
```

#### 方式 B：使用 Xcode

1. 打开 Xcode
2. 打开项目：`ios/Runner.xcworkspace`（注意是 `.xcworkspace` 不是 `.xcodeproj`）
3. 在顶部选择你的 iPhone 12 Pro Max 作为目标设备
4. 点击运行按钮（▶️）或按 `Cmd + R`

### 4. 如果遇到签名问题

如果出现签名错误，在 Xcode 中：

1. 选择 **Runner** 项目（左侧导航栏）
2. 选择 **Runner** target
3. 切换到 **Signing & Capabilities** 标签
4. 确保：
   - ✅ **Automatically manage signing** 已勾选
   - ✅ **Team** 已选择你的开发者账号（ZLLDAN62HX）
   - ✅ **Bundle Identifier** 是唯一的（例如：com.yourcompany.townpass）

### 5. 常见问题

#### 问题：设备显示为"未配对"
- **解决**：在 Xcode 的 Devices and Simulators 窗口中点击"Use for Development"

#### 问题：签名错误
- **解决**：确保在 Xcode 中选择了正确的 Team，并且 Bundle Identifier 是唯一的

#### 问题：找不到设备
- **解决**：
  1. 检查 USB 连接
  2. 在 iPhone 上重新信任电脑
  3. 重启 Xcode
  4. 运行 `flutter doctor` 检查环境

#### 问题：需要开发者账号
- **解决**：如果没有付费开发者账号，可以使用免费的 Apple ID：
  1. 在 Xcode → Preferences → Accounts 中添加你的 Apple ID
  2. 在 Signing & Capabilities 中选择该账号作为 Team

## 无线调试（可选）

配对成功后，可以启用无线调试：

1. 在 Xcode Devices and Simulators 窗口中
2. 勾选 **Connect via network**
3. 之后就可以断开 USB 线，通过 Wi-Fi 连接调试

## 注意事项

- 首次在真实设备上运行需要较长时间（编译和安装）
- 确保 iPhone 和 Mac 连接到同一个 Wi-Fi 网络（如果使用无线调试）
- 如果应用需要特殊权限（如定位、相机），首次运行时会提示授权


