# 示例：给一个 Web 应用加装守护（Deploy + Guardian quickstart）

场景：用 B1 部署一个 CLI 工具后，用 B2 守护它的关键配置文件。

## 1. 部署（B1）

```sh
# 先试运行，确认档案与链路可用
bash start-auto-deploy.sh profiles/codex.json --dry-run

# 真实部署
bash start-auto-deploy.sh profiles/codex.json
```

部署完成后会生成：
- 快照与 SHA256 凭证（回执 DK- 开头，可回溯）
- 《使用指南》速查卡（`$HOME/deploy-kit-使用指南.md`）

## 2. 登记基线（B2）

把部署中"装好就不该变"的关键文件登记进基线：

```sh
guardian/guardian.sh baseline add ~/.codex/auth.json
guardian/guardian.sh baseline add /etc/nginx/nginx.conf   # 举例
guardian/guardian.sh baseline list                        # 查看已登记
```

## 3. 启动守护

```sh
# 每小时一次：心跳（仅出站）+ 只读巡检；幂等，重复执行无副作用
guardian/guardian.sh heartbeat start
```

## 4. 看回执

```sh
guardian/guardian.sh page
# 打开 ~/.guardian/page/receipt.html
```

- 绿色行 `INFO`：一切如常
- 黄色行 `WARN`：文件内容漂移（比如有人改了配置）
- 红色行 `FAULT`：文件被删除——严重事故

## 5. 模拟一次漂移（体验分级）

```sh
# 故意改一个已登记的文件
echo "# edited by hand" >> ~/.codex/auth.json

# 立刻巡检一轮
guardian/guardian.sh patrol
guardian/guardian.sh page
# 回执页会出现 WARN 行，附新旧指纹（只展示前 12 位，不含内容）
```

## 6. 可选：接入上报

```sh
export GUARDIAN_WEBHOOK_URL="https://your-endpoint.example.com/hook"
guardian/guardian.sh heartbeat start   # 重启后生效
```

> 上报只含指纹与级别，不含文件内容；端点不可达只记日志，不阻断本地巡检。

## 7. 卸载（干净移除）

```sh
guardian/guardian.sh uninstall
# 删除全部守护文件与定时项，无残留
```
