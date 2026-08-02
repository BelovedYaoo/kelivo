# E2EE 明文偏好退役

- Issue：#99。
- 完成：安装级启动退役新增 17 个 Vault 旧明文键，覆盖供应商/API Key 与分组真值、搜索、网络 TTS、可移植 MCP 和 MCP 超时；匿名及全部注册账号命名空间均处理。
- 失败关闭：沿用耐久偏好删除证明；任一删除失败直接抛错，`main.dart` 在创建内容运行时前关闭资源并返回。
- 精确边界：保留 `provider_group_collapsed_v1`、`mcp_local_servers_v1`、`migrations_version_v1`、主题及其他非目标控制键。
- 验证：定向 `flutter analyze` 无问题；退役测试 8/8 通过，覆盖正常清理、缺键幂等、删除失败和独立字面量全集。
- 兼容：按硬切要求删除旧镜像，无迁移或兼容读取；E2EE Vault 是这些配置的唯一真值。
- 剩余明文面：本机 MCP stdio 配置、全局代理凭据、生成提示词/模型选择，以及 User/Assistant 等其他 Provider 的历史镜像不属于本分支，需分别迁入加密存储后退役。
