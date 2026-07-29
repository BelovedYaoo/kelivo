# 协作摘要

- 目标：实现附件下载协调器，并以事务前物化、事务内就绪断言阻止未完成附件页推进 checkpoint。
- 基线：`7debcb85`。
- 跟踪：https://github.com/BelovedYaoo/kelivo/issues/52
- 边界：下载协调器、pull 接线与现有测试；不实现旧附件格式兼容或迁移。
- 约束：所有 manifest、chunk 网络与文件 IO 均在 SQLCipher 事务外；事务内只读取持久状态、校验精确身份并注册引用。
- 完成：实现有界事务前下载、持久续传与退避、流式验密原子发布、事务内精确就绪断言，以及 pending/未来世代 checkpoint 门禁。
- 接线：生产运行时使用独立附件密码会话；消息远端 apply 复用 `replaceMessageAssetReferences`，空附件也原子清理旧引用。
- 依赖：基于附件密码会话与上传基础提交 `b808d0e3`，集成时应先合入该提交。
- 验证：数据库约束测试 84 项、附件协议测试 117 项、内容运行时相关测试 3 项通过；10 个改动相关文件定向 analyze 通过。
- 已知基线：全仓 analyze 被未改动的 `dependencies/mcp_client/test/**` 缺少 `package:test` 阻断，本任务文件无静态检查问题。
