#!/bin/bash

# 修复 Xcode 数据库锁定问题的脚本

echo "🔧 正在修复 Xcode 数据库锁定问题..."

# 1. 停止所有构建进程
echo "📛 停止所有构建进程..."
pkill -9 xcodebuild 2>/dev/null
pkill -9 clang 2>/dev/null
pkill -9 swift 2>/dev/null
pkill -9 ibtoold 2>/dev/null
pkill -9 -f "GradleDaemon" 2>/dev/null

# 2. 关闭 Xcode（如果正在运行）
echo "📛 关闭 Xcode..."
killall Xcode 2>/dev/null

# 3. 等待进程完全退出
sleep 2

# 4. 删除所有 DerivedData
echo "🗑️  清理 Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-* 2>/dev/null

# 5. 清理 Flutter 构建缓存
echo "🗑️  清理 Flutter 构建缓存..."
cd "$(dirname "$0")"
flutter clean > /dev/null 2>&1

echo "✅ 修复完成！"
echo ""
echo "现在可以重新运行："
echo "  flutter run -d ios"
echo ""
echo "或者如果使用 Android 模拟器："
echo "  flutter run -d android"

