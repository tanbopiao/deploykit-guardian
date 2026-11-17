#!/usr/bin/env bash
# auto-snapshot-backup.sh — 环境快照、压缩、（可选）rsync 至持久层
set -eu
source "$(dirname "$0")/../lib/common.sh"
SNAP="$DK_WORK/snapshot-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SNAP"
npm config get registry > "$SNAP/npm-registry.txt" 2>/dev/null || true
node -v > "$SNAP/node-version.txt" 2>/dev/null || true
env | grep -E '^(NVM_DIR|PATH)=' > "$SNAP/env-readonly.txt"   # 不含任何密钥（安全边界：密钥不落地）
cp "$(dirname "$0")/../profiles/"*.json "$SNAP"/ 2>/dev/null || true
TAR="$SNAP.tar.gz"; tar -czf "$TAR" -C "$SNAP" . && rm -rf "$SNAP"
if [ -n "${PERSIST_SSH:-}" ]; then rsync -az "$TAR" "$PERSIST_SSH" && dk_ok "快照已同步持久层 $PERSIST_SSH"; fi
dk_ok "快照 $TAR（sha256 $(sha256sum "$TAR" | awk '{print $1}' | cut -c1-16)…）"
echo "$TAR"
