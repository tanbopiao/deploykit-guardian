#!/usr/bin/env bash
# lib/common.sh — deploy-kit 公共库：日志、JSON 工具、熔断计数
# common library for deploy-kit: logging, JSON helpers, fuse counter
set -u
DK_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DK_WORK="${DK_WORK:-/tmp/deploy-kit}"
DK_LOG="$DK_WORK/run-$(date +%Y%m%d-%H%M%S).log"
DK_FUSE_MAX=3
mkdir -p "$DK_WORK"

dk_log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$DK_LOG" >&2; }
# 用法: dk_json_get <file> "<python表达式，可用 d 表示JSON对象>"
dk_json_get() { python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
v=eval(sys.argv[2])
print("" if v is None else v)
' "$1" "$2" 2>/dev/null; }
dk_fuse_load() { cat "$DK_WORK/fuse" 2>/dev/null || echo 0; }
dk_fuse_bump() {
  local n; n=$(( $(dk_fuse_load) + 1 )); echo "$n" > "$DK_WORK/fuse"
  dk_log "熔断计数 $n/$DK_FUSE_MAX"
  [ "$n" -ge "$DK_FUSE_MAX" ] && { dk_log "连续 $n 次校验失败，熔断：终止流程转人工，详见 $DK_LOG"; exit 70; }
  return 0
}
dk_fuse_reset() { echo 0 > "$DK_WORK/fuse"; }
dk_step() { dk_log "== $1"; }
dk_ok() { dk_log "OK  $1"; }
dk_trap_log() { printf '[%s] rc=%s\n' "$(date '+%F %T')" "$1" >> "$DK_LOG"; }
