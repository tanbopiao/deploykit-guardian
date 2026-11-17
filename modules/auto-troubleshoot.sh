#!/usr/bin/env bash
# auto-troubleshoot.sh — 故障自动匹配修复（EACCES / PATH / 网络超时 / 认证失败）
# 用法: auto-troubleshoot.sh <log文件或错误串>
set -u
source "$(dirname "$0")/../lib/common.sh"
BLOB="$(cat "$1" 2>/dev/null || echo "$1")"
fix() { dk_ok "自修复: $1"; }

case "$BLOB" in
  *EACCES*|*"Permission denied"*)
    npm config set prefix ~/.npm-global
    export PATH="$HOME/.npm-global/bin:$PATH"
    grep -q "npm-global" ~/.bashrc 2>/dev/null || echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
    fix "EACCES → npm 全局目录迁至用户域 ~/.npm-global，PATH 已更新" ;;
  *"command not found"*|*"not found"*"codex"*|*"not found"*"claude"*)
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    fix "PATH → nvm 环境重载（新终端请重开或 source ~/.bashrc）" ;;
  *"ETIMEDOUT"*|*"network"*|*"timeout"*|*"ECONNREFUSED"*)
    npm config set registry https://registry.npmmirror.com/
    fix "网络超时 → npm 镜像源切至 npmmirror，重试即可" ;;
  *401*|*403*|"auth"*)
    dk_log "认证失败（401/403）→ 密钥无效或无权限，属人工介入项，不自动重试"; exit 61 ;;
  *)
    dk_log "未匹配已知故障模式 → 转人工，日志 $DK_LOG"; exit 62 ;;
esac
