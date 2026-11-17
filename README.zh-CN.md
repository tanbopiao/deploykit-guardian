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
bash start-auto-deploy.sh profiles/codex.json --dry-run

# 真实部署
bash start-auto-deploy.sh profiles/codex.json

# 部署完成后登记基线指纹
guardian/guardian.sh baseline add /opt/myapp/main.conf

# 启动每小时心跳＋巡检（仅出站，不开端口）
guardian/guardian.sh heartbeat start

# 查看守护回执
guardian/guardian.sh page   # 打开 ~/.guardian/page/receipt.html
```

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

## 目录结构

```
├── start-auto-deploy.sh    # B1 总控（预检 → 部署 → 校验 → 台账）
├── guardian/               # B2 装后守护 v0
│   └── guardian.sh         # 心跳 / 巡检 / 回执页 / 卸载
├── lib/ modules/ profiles/ adapters/   # B1 模块
├── examples/               # 完整示例
├── tests/                  # 验收测试（沙箱全流程）
├── docs/                   # 安装指南与设计文档
└── ROADMAP.md              # B 系列产品线规划
```

## 状态

- B1：已交付（v1.1），生产环境在用。
- B2：v0 已实现，沙箱验收通过（见 `tests/e2e-run-*.log`）。
- B3/B4：规划中，见 [ROADMAP.md](ROADMAP.md)。

## 许可证

MIT —— 见 [LICENSE](LICENSE)。
