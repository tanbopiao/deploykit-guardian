#!/usr/bin/env bash
# auto-env-init.sh — nvm + Node 版本锁定 + npm 淘宝镜像基线
# 用法: auto-env-init.sh [node_version]   默认 22（Codex v22 LTS+ / Claude Code v18+）
set -eu
source "$(dirname "$0")/../lib/common.sh"
NODE_VER="${1:-22}"
REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"

if [ ! -d "${NVM_DIR:-$HOME/.nvm}" ]; then
  dk_step "安装 nvm"
  curl -sSf https://gitee.com/mirrors/nvm/raw/master/install.sh | bash
fi
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

if ! nvm ls "$NODE_VER" >/dev/null 2>&1; then
  dk_step "安装 Node v$NODE_VER（镜像源加速）"
  NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node nvm install "$NODE_VER"
fi
nvm use "$NODE_VER" >/dev/null
dk_ok "Node $(node -v) 在役"

npm config set registry "$REGISTRY"
dk_ok "npm 镜像源 → $REGISTRY"

# shell rc 持久化（仅追加本套件必需行，不覆盖既有配置）
RC="$HOME/.bashrc"; [ "$(uname -s)" = "Darwin" ] && [ ! -f "$RC" ] && RC="$HOME/.zshrc"
grep -q "NVM_DIR" "$RC" 2>/dev/null || printf '\nexport NVM_DIR="%s"\n[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n' "$NVM_DIR" >> "$RC"
dk_ok "终端环境已持久化 → $RC"
