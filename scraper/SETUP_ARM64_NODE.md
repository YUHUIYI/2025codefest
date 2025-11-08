# 安裝 arm64 版本的 Node.js（可選）

如果您想消除性能警告並獲得更好的性能，可以安裝 arm64 版本的 Node.js。

## 方法 1：使用 nvm（推薦）

```bash
# 安裝 nvm（如果還沒安裝）
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# 重新載入 shell
source ~/.zshrc

# 安裝 arm64 版本的 Node.js
nvm install --lts
nvm use --lts

# 確認架構
node -p "process.arch"  # 應該顯示 'arm64'
```

## 方法 2：直接從官網下載

1. 前往 https://nodejs.org/
2. 下載 macOS ARM64 版本
3. 安裝後確認：`node -p "process.arch"` 應該顯示 `arm64`

## 注意事項

- 安裝新的 Node.js 後，需要重新執行 `npm install`
- 這不是必須的，只是為了更好的性能

