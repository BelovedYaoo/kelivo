# 协作摘要

- 目标：为 Issue #50 建立经过 ARK 认证的逻辑记录状态与 SQLCipher 防回滚账本，删除使用密文墓碑并统一走 put。
- 边界：不启用生产远端写入，不改变 v3 wire 与服务端 D1 契约，不信任服务端 revision、delete 或时间戳。
- 完成：账户记录状态使用最多双父摘要的认证 DAG，值/墓碑、逻辑版本、操作 ID 与写入设备声明均位于 ARK 密文内；外层摘要绑定信封版本、不透明记录 ID、key epoch 与完整密文。
- 完成：写入设备字段明确为未签名的 `claimedWriter*`，不得用于授权或撤销；只有 SQLCipher 账本接受结果才能决定 head、冲突、重放或历史缺口。
- 完成：出站只接受认证状态且要求 `mutationId == operationId`；入站 raw delete/deleted 使整页失败，墓碑统一作为密文 put。
- 完成：SQLCipher v13 状态/父边/head 三表、DAG 接受状态机与冻结 schema 已生成；重放会核对元数据、父边和非空 head 集，操作 ID 在账户内全局唯一。
- 跟踪：附件分块加密不属于本分支，已建立 Issue #52。
- 验证：格式化与 `flutter analyze --no-pub lib test` 通过；数据库 120 项、同步协议 75 项、状态密码学 15 项测试通过。功能工作树清理缓存后，Flutter native hook 首次构建成功但进程持锁不返回，全量测试改在 main 工作树补跑。
- 剩余：生产同步引擎必须按账本接受结果落地，持久化并逐字节重用 sealed outbox；新设备的全局回滚/遗漏防护仍需账户 checkpoint 与设备签名。
