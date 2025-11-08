#!/bin/bash

# 过滤 Android logcat 中的 OpenGL ES 错误
# 使用方法: ./filter_logcat.sh

echo "📱 开始监听 Android 日志（已过滤 OpenGL ES 错误）..."
echo "按 Ctrl+C 停止"
echo ""

# 过滤掉 libEGL 相关的错误
adb logcat | grep -v "E/libEGL.*called unimplemented OpenGL ES API"

