# 示例：新增一个部署目标（custom profile）

三步上架一个新产品：复制模板 → 改字段 → 试运行。

## 1. 复制通用模板

```sh
cp profiles/generic-npm-agent.json profiles/my-agent.json
```

## 2. 修改字段

```json
{
  "name": "My Agent CLI",
  "npm_package": "@scope/my-agent",
  "node_version": "22",
  "config_dir": "~/.myagent",
  "config_file": "config.json",
  "config_template": "{ \"API_KEY\": \"{{API_KEY}}\", \"BASE_URL\": \"{{BASE_URL}}\" }",
  "env_keys": ["MY_AGENT_API_KEY"],
  "verify_command": "my-agent --version >/dev/null 2>&1",
  "docs_url": "https://example.com/docs"
}
```

字段说明：

| 字段 | 说明 |
|---|---|
| `npm_package` | npm 包名（部署方式：`npm install -g`） |
| `node_version` | 需要的 Node 大版本（预检与安装用） |
| `config_dir` / `config_file` | 配置文件写入位置 |
| `config_template` | 配置模板；`{{API_KEY}}` 必填，`{{BASE_URL}}`/`{{MODEL}}` 可用命令行覆盖 |
| `env_keys` | 配置模板中引用的环境变量名 |
| `verify_command` | 部署后验证命令（退出码 0 = 通过） |

## 3. 试运行

```sh
bash start-auto-deploy.sh profiles/my-agent.json --dry-run
# 档案可解析即通过；随后去掉 --dry-run 真实部署
```

## 4. 部署后加守护（推荐）

```sh
guardian/guardian.sh baseline add ~/.myagent/config.json
guardian/guardian.sh heartbeat start
```

配置文件被意外改动时，回执页会出现 WARN，并在下一次心跳时上报。
