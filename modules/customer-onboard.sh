#!/usr/bin/env bash
# customer-onboard.sh — 客户教学与售后交付：部署完成后生成《使用指南》速查卡
# 用法: customer-onboard.sh <profile.json>
set -u
source "$(dirname "$0")/../lib/common.sh"
PF="$1"
NAME=$(dk_json_get "$PF" "d['name']")
VERIFY=$(dk_json_get "$PF" "d.get('verify_command','')")
DOCS=$(dk_json_get "$PF" "d.get('docs_url','')")
OUT="${DK_GUIDE:-$HOME/deploy-kit-使用指南.md}"

cat > "$OUT" <<EOF
# $NAME 使用指南（deploy-kit 自动生成）

## 一、安装好了怎么用
- 打开新终端（或执行 \`source ~/.bashrc\`），直接敲产品命令即可启动。
- 验证命令：\`$VERIFY\`
- 官方文档：$DOCS

## 二、常见报错速查（配 auto-troubleshoot.sh 自动修复）
| 现象 | 说明 | 自动修复 |
|---|---|---|
| EACCES / Permission denied | npm 全局目录权限 | 自动迁至 ~/.npm-global 并更新 PATH |
| command not found | 终端 PATH 未刷新 | 自动重载 nvm 环境，重开终端即可 |
| ETIMEDOUT / network | 国内网络依赖下载超时 | 自动切换 npmmirror 镜像源 |
| 401 / 403 | 密钥无效或无权限 | 转人工核对密钥（不自动重试） |

一键自修复：\`bash <deploy-kit目录>/modules/auto-troubleshoot.sh "<报错信息>"\`

## 三、售后与增值
- 重装 / 换机 / 新增环境：本地一键重跑 \`start-auto-deploy.sh <profile>\`，无需重复人工配置。
- 部署全程留有快照与台账凭证（DK- 开头回执），可随时回溯。
- 遇到本指南未覆盖的问题，直接联系技术支持（附上日志文件路径）。
EOF
chmod 600 "$OUT"
dk_ok "客户使用指南已生成：$OUT"
echo "GUIDE_OK $OUT"
