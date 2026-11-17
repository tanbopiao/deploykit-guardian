#!/usr/bin/env bash
# auto-precheck.sh — 预检模块：输出结构化 JSON 报告（作为调度判断依据）
set -u
source "$(dirname "$0")/../lib/common.sh"
OUT="${1:-$DK_WORK/precheck.json}"
os_type="$(uname -s)"; arch="$(uname -m)"
node_ver="$(command -v node >/dev/null 2>&1 && node -v 2>/dev/null || echo none)"
npm_ver="$(command -v npm >/dev/null 2>&1 && npm -v 2>/dev/null || echo none)"
nvm_dir="${NVM_DIR:-$HOME/.nvm}"; nvm_ok="false"; [ -d "$nvm_dir" ] && nvm_ok="true"
mem_mb="$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)"
disk_free_gb="$(df -k "$HOME" 2>/dev/null | awk 'NR==2{printf "%d",$4/1048576}')"
disk_free_gb="${disk_free_gb:-0}"
net_npm="false"; curl -sfm 6 -o /dev/null https://registry.npmmirror.com/ && net_npm="true"
net_ext="false"; curl -sfm 6 -o /dev/null https://registry.npmjs.org/ && net_ext="true"
wsl="false"; grep -qi microsoft /proc/version 2>/dev/null && wsl="true"

printf '{"os":"%s","arch":"%s","wsl":%s,"node":"%s","npm":"%s","nvm":%s,"mem_mb":%s,"disk_free_gb":%s,"net_npm_mirror":%s,"net_npm_org":%s}' \
  "$os_type" "$arch" "$wsl" "$node_ver" "$npm_ver" "$nvm_ok" "$mem_mb" "$disk_free_gb" "$net_npm" "$net_ext" \
| python3 -c '
import json,sys
d=json.load(sys.stdin)
d["verdict"]="PASS" if (d["mem_mb"]>=2048 and d["disk_free_gb"]>=5 and (d["net_npm_mirror"] or d["net_npm_org"])) else "DEGRADE"
d["notes"]=[]
if d["mem_mb"]<2048: d["notes"].append("内存<2G，建议降级GUI模式")
if d["disk_free_gb"]<5: d["notes"].append("磁盘<5G，先清理")
open(sys.argv[1],"w").write(json.dumps(d,ensure_ascii=False,indent=1))
print(json.dumps(d,ensure_ascii=False,indent=1))
' "$OUT"
