# 协作摘要

- 已完成 SQLCipher v14 持久化意图、认证 operation、sealed outbox 与远端安全门；outbox 不保存明文。
- 本地写、封装、认领、未知结果重试、applied、conflict、rejected、隔离和启动恢复均使用事务与租约 CAS。
- 重试逐字节复用 operationId、expectedRevision、digest 和 ciphertext；远端 revision/changeSeq 与安全门只允许单调推进。
- startup recovery 仅能由数据库仓储私有调用；同一数据库的 outbox 服务实例具备唯一所有权。
- 已覆盖只读快照、历史 key epoch、未来 epoch 不阻塞同批、显式 token 绑定及 v14 原始 schema 校验。
- 生产远端同步尚未启用；后续继续实现业务实体 codec、pull/checkpoint、设备签名与应用启动接线。
