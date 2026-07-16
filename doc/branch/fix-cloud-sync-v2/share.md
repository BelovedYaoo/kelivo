# fix/cloud-sync-v2 协作记录

- 目标：将云同步协议升级到 v2，修复契约拒绝、重复重投、冲突丢数据和 Android UI 卡顿。
- 分支：`fix/cloud-sync-v2`，基于 `main@783bb62a`；完成后合并回 `main` 并清理 worktree。
- 测试 seam：同步 journal/outbox 模块、批量 Adapter 接口、生成客户端传输闭环。
- 当前阶段：v2 契约与 outbox 状态机 TDD 实施中，尚未执行生产数据重建。
- 协作约束：不要修改平台生成文件；同步协议、Hive 状态和 Provider 写入口变更需先在此记录。
- 已完成：永久拒绝的 outbox 项持久化 `blockedAt` 与错误码，保留原请求但排除自动发送、重试和合并；目标测试已通过。
- 已完成：同步协调器通过最小传输接口处理 push/pull/snapshot；服务端返回 `rejected` 时保留并阻塞原 mutation，后续同步不会重投；目标测试与静态分析已通过。
- 已完成：Flutter 本地实体默认使用 schema v2；消息父级改为轮次；配置 Payload 以 envelope 为唯一身份、有序实体强制 `_position`；指令注入升级为独立实体；相关 26 项测试与定向静态分析通过。
- 已完成：push、pull、snapshot 统一发送 `X-Kelivo-Sync-Protocol-Version: 2`；真实本地 HTTP 传输测试与定向静态分析通过。
- 已完成：新增持久写前 `SyncWriteJournal` 深模块；支持稳定本地作用域、失败/延迟恢复、同实体串行、异实体并发、远端应用隔离及会话切换门闩；9 项目标测试与定向静态分析通过，尚未接入领域写入口。
