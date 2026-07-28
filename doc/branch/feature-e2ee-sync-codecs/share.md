# 协作摘要

- 已完成服务端与客户端 v3 认证密文增量拉取、全历史快照及显式 reset 协议，正式服务域名仅使用 `kelivo.bemylover.top`。
- 客户端使用 SQLCipher schema v15 原子提交 ledger、业务 apply、远端元数据与 checkpoint；v1 至 v14 本地库及损坏回执均直接删除重建，不保留明文迁移路径。
- 六类聊天实体使用严格、确定性的规范 JSON codec，校验记录身份、字段、数值、时间、Unicode 与 64 层嵌套上限。
- HTTP 边界和协调器均拒绝非空原地游标；页内冲突保留最后一个可应用祖先；未来密钥世代不会错误前移 checkpoint。
- 验证：高风险组合 197/197 通过；串行完整测试 1623 通过、19 跳过；`lib`、`test` 与生成 API 客户端静态分析零问题。
- 生产内容同步仍保持 `contentSyncEnabled=false`，后续需接入业务写入/outbox、配置 SQL 化、调度、设备签名、附件 R2 与恢复配对流程。
- 默认并发完整测试可能阻塞，已登记 Issue #53；根目录分析仍受既有 Issue #33 的 `mcp_client` 测试依赖缺失阻断。
