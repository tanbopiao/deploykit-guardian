#!/usr/bin/env bash
# start-auto-deploy.sh — 总控：读预检结果分流（无人值守 / GUI兜底 / dry-run），串联全链
# 用法: start-auto-deploy.sh <profile.json> [--dry-run] [--base-url URL] [--model MODEL]
set -u
source "$(dirname "$0")/lib/common.sh"
PF=""; DRY=""; BASE=""; MODEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY="1";; --base-url) BASE="$2"; shift;; --model) MODEL="$2"; shift;;
    *) PF="$1";;
  esac; shift
done
[ -n "$PF" ] || { echo "用法: $0 <profile.json> [--dry-run] [--base-url URL] [--model MODEL]"; exit 64; }
[ -n "$DRY" ] && MODE="dry-run沙箱" || MODE="无人值守"
dk_fuse_reset
dk_step "deploy-kit 总控启动（模式：$MODE）"

# 1) 预检
"$DK_HOME/modules/auto-precheck.sh" >/dev/null
VERDICT=$(dk_json_get "$DK_WORK/precheck.json" "d['verdict']")
dk_ok "预检判定: $VERDICT（$( [ "$VERDICT" = "PASS" ] && echo 无人值守模式 || echo 降级：GUI+脚本兜底 )）"

# 2) 环境基线（dry-run 跳过真实安装）
if [ -z "$DRY" ]; then "$DK_HOME/modules/auto-env-init.sh" "$(dk_json_get "$PF" "d['node_version']")"; fi

# 3) 目标部署（dry-run 只校验档案）
if [ -n "$DRY" ]; then
  dk_ok "dry-run：档案可解析（name=$(dk_json_get "$PF" "d['name']")），跳过真实安装"
else
  if ! "$DK_HOME/modules/deploy-target.sh" "$PF"; then
    dk_fuse_bump; "$DK_HOME/modules/auto-troubleshoot.sh" "$DK_LOG" || true
    "$DK_HOME/modules/deploy-target.sh" "$PF" || { dk_fuse_bump; }
  fi
fi

# 4) API 连通校验（密钥仅内存，本步结束即销毁）
if [ -n "$BASE" ]; then
  [ -z "$API_KEY" ] && { read -rs -p "API Key: " API_KEY; echo; }
  export API_KEY
  if python3 "$DK_HOME/modules/api-verify.py" "$BASE" "$API_KEY" "$MODEL"; then
    dk_ok "API 连通与配额校验通过"
  else
    dk_fuse_bump
  fi
  unset API_KEY
fi

# 4.5) 客户教学交付：生成《使用指南》速查卡（含常见报错速查）
"$DK_HOME/modules/customer-onboard.sh" "$PF" || true

# 5) 快照 + 台账
TAR=$("$DK_HOME/modules/auto-snapshot-backup.sh")
printf '{"mode":"%s","profile":"%s","snapshot":"%s"}\n' "$MODE" "$(basename "$PF")" "$TAR" > "$DK_WORK/report.json"
"$DK_HOME/modules/auto-ledger-record.py" "$DK_WORK/report.json"
dk_ok "交付完成；密钥已销毁，SSH 会话请随终端退出自动断开（不留常驻连接）"
