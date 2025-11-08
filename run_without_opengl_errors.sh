#!/bin/bash

# 运行 Flutter 应用并过滤掉 OpenGL ES 错误日志
# 使用方法: ./run_without_opengl_errors.sh

echo "🚀 启动 Flutter 应用（已过滤 OpenGL ES 错误）..."
echo ""

# 过滤掉 libEGL 相关的错误日志，同时保留其他所有输出
flutter run 2>&1 | grep --line-buffered -v "E/libEGL.*called unimplemented OpenGL ES API"

