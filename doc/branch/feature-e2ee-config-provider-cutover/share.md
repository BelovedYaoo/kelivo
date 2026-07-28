# E2EE 配置 Provider 硬切

- 新增配置 Provider 桥接，覆盖十类配置实体和八个偏好单例；生产启动从 SQLCipher Vault 水合。
- 本地业务内存、Vault 与 outbox intent 同事务提交，失败从已回滚 Vault 恢复；远端提交后刷新 Provider，失败关闭。
- 账号配置不再读取或双写旧 SharedPreferences/Store；stdio MCP 与世界书折叠状态明确保留为本机状态。
- 生产运行时强制绑定配置桥接，`main.dart` 已完成依赖注入和初始化顺序约束。
- 相关 40 项测试通过，全部变更文件定向分析零问题；全仓分析受 `dependencies/mcp_client` 缺少 `package:test` 阻断，全仓测试运行十分钟无输出后超时。
- 未修改数据库 schema、ChatDatabaseRepository 或附件模块。
