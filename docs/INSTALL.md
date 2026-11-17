# 安装指南（Install Guide）

## 前置条件（Prerequisites）

- Linux / macOS / WSL2；bash 3.2+
- `bash`、`python3`（≥3.8）、`curl`（可选，用于 webhook 上报与 npm 镜像探测）
- 预检会自动检查：内存 ≥ 2G、磁盘可用 ≥ 5G、npm 镜像连通性，不满足时自动降级为 GUI 兜底模式

## 安装 B1 一键部署套件

```sh
# 1) 克隆本仓库
git clone <repo-url> deploykit-guardian && cd deploykit-guardian

# 2) 试运行（不改动系统，校验档案与链路）
bash start-auto-deploy.sh profiles/codex.json --dry-run

# 3) 真实部署（按 profile 安装目标 CLI 并写入配置）
bash start-auto-deploy.sh profiles/codex.json
#   可选参数：--base-url URL  --model MODEL
#   API Key 仅在内存注入，流程结束即销毁，不落盘
```

### 新增一个部署目标

新增产品＝在 `profiles/` 加一份 JSON：

```json
{
  "name": "My Agent CLI",
  "npm_package": "@scope/my-agent",
  "node_version": "22",
  "config_dir": "~/.myagent",
  "config_file": "config.json",
  "config_template": "{ \"API_KEY\": \"{{API_KEY}}\" }",
  "env_keys": ["API_KEY"],
  "verify_command": "my-agent --version >/dev/null 2>&1"
}
```

模板变量：`{{API_KEY}}`（必填）、`{{BASE_URL}}`、`{{MODEL}}`（可选）。

### 常见报错速查

| 现象 | 处理 |
|---|---|
| EACCES / Permission denied | 自动迁至 `~/.npm-global` 并更新 PATH |
| command not found | 重开终端刷新 PATH（自动重载 nvm） |
| ETIMEDOUT | 自动切换 npmmirror 镜像源 |
| 401 / 403 | 密钥无效，人工核对（不自动重试） |

连续 3 次校验失败自动熔断，转人工，全步日志在 `$DK_WORK/run-*.log`。

## 安装 B2 装后守护（Post-Deploy Guardian）

> B1 部署完成后即进入守护态；也可以独立使用。

```sh
# 1) 部署完成后，登记需要看护的文件基线（只读登记）
guardian/guardian.sh baseline add /opt/myapp/main.conf
guardian/guardian.sh baseline add /opt/myapp/app.ini

# 2) 启动每小时心跳＋巡检（仅出站，不开端口；幂等可重复执行）
guardian/guardian.sh heartbeat start

# 3) 立即手动巡检一轮（可选）
guardian/guardian.sh patrol

# 4) 查看守护回执页
guardian/guardian.sh page
#    页面位置：~/.guardian/page/receipt.html（无需登录）
```

### 可选配置（环境变量）

| 变量 | 默认 | 说明 |
|---|---|---|
| `GUARDIAN_HOME` | `~/.guardian` | 守护数据根目录（卸载即删） |
| `GUARDIAN_WEBHOOK_URL` | 空 | 上报地址（可选；只发指纹与级别，不发内容） |
| `GUARDIAN_HEARTBEAT_INTERVAL` | 3600 | 心跳间隔（秒） |
| `GUARDIAN_MAX_PAGES` | 50 | 回执页保留的最近轮数 |

### 验收（沙箱全流程）

```sh
bash tests/test_guardian_e2e.sh
```

覆盖：登记基线 → 巡检（info）→ 制造漂移（warn）→ 删除文件（fault）→ 回执页可见 → 卸载无残留。

## 卸载

```sh
# B2 守护：一条命令干净移除（含定时项）
guardian/guardian.sh uninstall

# B1 套件：删除仓库目录即可；台账在 ~/.deploy-kit/ledger.jsonl，按需保留或删除
```

## 安全边界

- API Key 仅内存注入，流程结束即销毁；快照不含密钥；
- 守护组件只读巡检，不改动被守护系统，不自动修复/重启；
- 心跳与上报仅出站；回执与上报只含指纹，不含文件内容；
- npm 全局目录限用户域；所有变更带时间戳日志，可回溯。
