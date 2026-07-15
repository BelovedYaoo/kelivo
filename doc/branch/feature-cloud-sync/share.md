# feature/cloud-sync 协作记录

- 目标：接入 Kelivo 私有同步服务，实现账户、设备、聊天与配置多端同步及云端附件。
- 当前阶段：服务端协议实现中，客户端准备接入生成的 OpenAPI Dio 客户端。
- 主要边界：LLM 对话请求仍由客户端直连供应商；同步服务只接收账户、配置、会话记录和附件元数据。
- 本地专属数据：代理、窗口、热键、平台运行状态、STDIO MCP、备份凭据及设备同步凭据不上传。
- 验收：代码生成、格式化、分析、现有测试、Android APK 构建和线上同步闭环均通过。
- 协作注意：其他进程修改聊天模型、Hive 字段、Provider 初始化或附件 marker 前，请先在此记录，避免产生并行迁移冲突。
- 已完成：ChatMessage 增加稳定 turnId 与生成状态，修复新消息 groupId 默认值；AssistantMemory 增加可确定性迁移的 syncId。
- 已完成：发送与重生成共享 turnId，完成、取消、错误和崩溃恢复会写入准确终态；旧消息按逻辑组一次性迁移。
- 客户端契约：固定 OpenAPI Generator 7.23.0，使用 `dart-dio + built_value` 保留判别联合；生成包位于 `dependencies/kelivo_sync_api_client`，禁止手改生成文件。
- 配置同步：已完成供应商、助手、记忆、世界书、快捷短语、搜索、网络 TTS、HTTP/SSE MCP 及显式用户偏好适配；代理、本地文件、STDIO MCP、备份和运行态保持本地专属。
