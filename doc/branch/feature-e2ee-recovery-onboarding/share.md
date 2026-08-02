# 恢复专用 OPAQUE Onboarding Lease

- 已完成：`E2eeAccountRecoveryAuthentication.begin(...)` 复用普通 OPAQUE 登录事务并返回独占 lease；服务端 pending `authGeneration` 被严格保留，目标代次取相邻下一代。
- 资源边界：lease 私有持有设备槽、身份和源状态，blob 仅返回独立副本；关闭会撤销能力、等待在途证明、清零内部 blob、关闭句柄并释放认证预约。
- 验证：改动文件定向分析通过；同步协议测试 175 项通过；安全核心 OPAQUE 状态消费测试 2 项通过。
- 门禁缺口：仓库缺少能响应随机客户端请求的本机 OPAQUE server fixture，真实 `begin` 成功集成路径继续由 #38 跟踪，不增加测试注入或公开构造入口。
- 合并提示：`cloud_sync_client.dart` 仅在 OPAQUE approval 映射处新增一行，主分支的新会话解析改动可能造成同文件上下文冲突。
