# DeployKit Guardian（部署守护）

[English](README.md) · **简体中文**

> 一条命令部署，一个守护盯着。

**装一次，管到底。**

DeployKit Guardian 是一套开源的**装后守护**工具，为"一键部署"装出来的系统提供部署完成之后的看护能力。装完只是开始：谁来盯着、漂移了怎么发现、坏了谁先知道——守护回答这个问题：**装好的系统自己会说话。**

- **B1 —— 一键部署套件**（已含）：全自动部署脚本，带预检、自动排障、快照备份和只增不覆盖的审计台账。
- **B2 —— 装后守护 v0**（已含）：每小时心跳（仅出站）、只读基线指纹巡检、三级异常分级、静态回执页。
- **B3 —— 部署包档案市场**（规划中）：部署包的公开档案，含适用环境与验证记录。
- **B4 —— 网站部署通道**（规划中）：面向非开发者的拖拽式一键上线。

## 快速开始

```sh
# 部署（dry-run 校验档案与链路）
./start.sh deploy profiles/codex.json --dry-run

# 真实部署
./start.sh deploy profiles/codex.json

# 部署完成后登记基线指纹
./start.sh guardian baseline add /opt/myapp/main.conf

# 启动每小时心跳＋巡检（仅出站，不开端口）
./start.sh guardian heartbeat start

# 查看守护回执
./start.sh guardian page   # 打开 ~/.guardian/page/receipt.html
```

`start.sh` 只是统一 Python 入口 `start.py` 的薄包装（见下方「平台支持」）；
原有的 `bash start-auto-deploy.sh …` 与 `guardian/guardian.sh …` 用法保持不变。

## 平台支持

| 能力 | Linux | macOS | Windows 原生 | WSL2 |
| --- | --- | --- | --- | --- |
| B1 部署流水线 | ✅（bash，原始路径） | ✅ | 经 WSL2（检测到 WSL2 时 `start.py deploy` 自动委托） | ✅ |
| B2 守护核心 | ✅ cron 心跳 | ✅ cron 心跳（默认） | — | ✅ cron 心跳 |
| B2 守护原生定时 | — | 可选 launchd 适配（`guardian/adapters/macos/`） | ✅ schtasks 每小时任务（`guardian/adapters/windows/guardian.ps1`） | — |
| 回执页 / 巡检 / 干净卸载 | ✅ | ✅ | ✅ | ✅ |
| 启动入口 | `start.sh` / `start.command` | `start.sh` / `start.command`（双击友好） | `start.cmd`（调 `start.py`，守护委托 PowerShell 适配层） | `start.sh` |

全平台共享同一套设计保证：仅出站、只读巡检、只传指纹不传内容、一条命令
干净卸载（`start.py guardian uninstall` / `guardian.ps1 uninstall`）。
平台差异（定时方式、哈希工具、出站请求）全部收敛在
[`guardian/adapters/`](guardian/adapters/README.md)。

## 设计保证（v0）

| 保证 | 实现方式 |
| --- | --- |
| 仅出站 | 守护不开任何入站端口；心跳与上报均为客户端 POST |
| 只读巡检 | 巡检只比对指纹，不改动被守护系统 |
| 漂移记录不修复 | 自动修复不在 v0 范围（见 ROADMAP） |
| 卸载干净 | `guardian.sh uninstall` 一条命令移除定时项与全部文件 |
| 隐私 | 回执与上报只含指纹，不含文件内容 |

## 守护分级

- `info` —— 全部基线一致
- `warn` —— 发现漂移（内容变化）
- `fault` —— 基线文件被删除（或检查脚本报错升级）

## 部署档案（B3）

每次自动部署都会记入只增不覆盖的本地台账。一条命令即可生成对外静态档案——
JSON 台账加单文件 HTML 页，展示包编号、适用环境、验证状态与 SHA-256 指纹；
客户内容与绝对路径按构造即被剔除，绝不外泄：

```sh
python3 modules/archive-market.py build --out ./archive
```

## 网站部署通道（B4）

面向非开发者：四步向导引导页（准备压缩包 → 提交需求单 → 自动部署 → 验收回执）
加接单看板（订单号/类型/状态）。客户备注绝不出现在公开看板上：

```sh
python3 modules/site-channel.py intake add --type static-site
python3 modules/site-channel.py board --out ./channel
python3 modules/site-channel.py guide --out ./channel
```

## 目录结构

```
├── start.py                # 跨平台统一入口（deploy / guardian）
├── start.sh                # POSIX 薄包装（Linux / macOS / WSL2）
├── start.command           # macOS 薄包装（双击友好）
├── start.cmd               # Windows 薄包装
├── start-auto-deploy.sh    # B1 总控（预检 → 部署 → 校验 → 台账）
├── guardian/               # B2 装后守护 v0
│   ├── guardian.sh         # 心跳 / 巡检 / 回执页 / 卸载（默认 cron）
│   └── adapters/           # 平台适配层（windows / macos）
├── lib/ modules/ profiles/ adapters/   # B1 模块（含 archive-market.py、site-channel.py）
├── examples/               # 完整示例
├── tests/                  # 验收测试（沙箱全流程 + 入口分发）
├── docs/                   # 安装指南与设计文档
└── ROADMAP.md              # B 系列产品线规划
```

## 状态

- B1：已交付（v1.1），生产环境在用。
- B2：v0 已实现，沙箱验收通过（见 `tests/e2e-run-*.log`）。
- B3：v0 已实现，沙箱验收通过（13/13，`tests/test_archive_market.sh`）。
- B4：v0 已实现，沙箱验收通过（13/13，`tests/test_site_channel.sh`）。

## 许可证

MIT —— 见 [LICENSE](LICENSE)。
