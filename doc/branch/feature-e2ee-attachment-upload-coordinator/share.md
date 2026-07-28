# 协作摘要

- 基线：`d1b496771a00a58c674782b1d8bfc341c0705153`。
- 新增通用 `E2eeAttachmentCrypto` 与双 ARK `E2eeAttachmentCryptoSession`；密钥仅以原生句柄存在，seal 仅接受当前 epoch，open 接受历史 epoch 并拒绝未来 epoch。
- 新增仅公开 `advance(maximumRemoteSteps)`、`close()` 的上传协调器；严格限制远端步数，复用持久 mutation，支持 pending 密文精确重放、退避、永久失败和可重试关闭。
- 文件存储新增一次全量认证的内容读取会话；同一文件句柄生成分块摘要，后续逐块复核，避免路径替换窗口和逐块全文件扫描。
- 租约在每个远端步骤前复核，远端步骤后释放并重新 claim；create、put、commit 跨越租约时只重放对应 mutation，未知错误不会因过期被吞掉。
- 验证：定向 `flutter analyze` 通过；同步协议测试 112/112、附件持久上传状态测试 4/4 通过。
- 未覆盖：消息资产发现与 commit 后引用回填仍需 schema 增加 `targetRevisionId + targetOrdinal`，禁止使用 `localAssetId` 猜测映射。
