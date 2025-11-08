#!/bin/bash

# 動滋券爬蟲 - 推送到 GitHub 腳本

echo "準備推送到 GitHub..."
echo ""

# 檢查是否已設定遠程倉庫
if git remote | grep -q origin; then
    echo "✓ 遠程倉庫已設定"
    git remote -v
else
    echo "設定遠程倉庫..."
    read -p "請輸入 GitHub 倉庫名稱 (預設: dongzi-scraper): " repo_name
    repo_name=${repo_name:-dongzi-scraper}
    git remote add origin https://github.com/HenryLin1101/${repo_name}.git
    echo "✓ 已設定遠程倉庫: https://github.com/HenryLin1101/${repo_name}.git"
fi

echo ""
echo "推送代碼到 GitHub..."
git push -u origin main

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ 成功推送到 GitHub!"
    echo "倉庫網址: https://github.com/HenryLin1101/$(git remote get-url origin | sed 's/.*\///' | sed 's/\.git$//')"
else
    echo ""
    echo "✗ 推送失敗"
    echo "請確認："
    echo "1. 已在 GitHub 上建立倉庫"
    echo "2. 倉庫名稱正確"
    echo "3. 有推送權限"
fi

