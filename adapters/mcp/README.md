# MCP 适配（任意支持MCP的客户端）
暴露两个工具：
- deploy.run(profile, base_url, model)：调用 start-auto-deploy.sh
- deploy.status()：读取最近交付报告与台账回执
密钥经由客户端安全录入传参，MCP 进程内存态使用，结束后清理，不持久化。
