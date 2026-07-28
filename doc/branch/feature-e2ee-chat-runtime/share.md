# 协作摘要

- 目标：硬切接通六类聊天实体的本地事务 outbox、加密推送与远端 apply，生产不再使用仅本地同步写入器。
- 跟踪：https://github.com/BelovedYaoo/kelivo/issues/50
- 当前：只读审计已完成，进入六类聊天实体的数据面、账户密钥运行时与调度器实现。
- 已完成：本地业务写、sync intent 与 dirty 收口已改为同一 SQLCipher 事务；异常整体回滚。
- 已完成：CloudSyncProvider 已建立失败关闭的内容运行时合同，运行时初始化成功后才打开内容门；登出与重启会优先关闭内容运行时并始终清理会话/释放工作区租约。
- 已确认：生产仍注入 `LocalOnlySyncWriteExecutor` 且内容同步门关闭；现有 outbox、pull、严格 payload codec 尚无生产组装点。
- 实现顺序：先收紧本地事务和 key 覆盖，再建立聊天 snapshot/apply adapter，最后接通 ARK 运行时、调度与生命周期。
- 已知阻塞：附件 ID/顺序模型需与 R2 协议统一；turn tombstone 删除接口需改为按 turnId 幂等处理。
- 约束：不保留旧数据、旧 payload 或双写兼容路径；业务接线完成并验证前不提前开启内容同步。
