# 协作摘要

- 目标：硬切接通六类聊天实体的本地事务 outbox、加密推送与远端 apply，生产不再使用仅本地同步写入器。
- 跟踪：https://github.com/BelovedYaoo/kelivo/issues/50
- 当前：生产聊天内容运行时已经接入；配置 Vault 数据面、附件安全核心与认证 manifest 已合并，仍需完成配置生产接线和附件传输/持久化/领域闭环。
- 已完成：本地业务写、sync intent 与 dirty 收口已改为同一 SQLCipher 事务；异常整体回滚。
- 已完成：CloudSyncProvider 已建立失败关闭的内容运行时合同，运行时初始化成功后才打开内容门；登出与重启会优先关闭内容运行时并始终清理会话/释放工作区租约。
- 已完成：认证与运行时共用设备状态访问，持久会话硬切 schema v3 并绑定设备密钥版本；ARK 租约严格核对账户、设备与世代后仅允许一次所有权转移。
- 已完成：六类聊天实体支持严格快照读取与事务内远端应用；依赖顺序、墓碑顺序、幂等 turn 删除、无 outbox 回声及拉取生命周期均已有回归门禁。
- 已完成：账户记录信封、会话和安全核心统一接受完整正 uint32 keyEpoch，拒绝零与超界值。
- 已完成：持久账户会话提供唯一认证会话转换入口，Provider 配对批准与后续 transport 不再丢失已验证的 deviceKeyVersion。
- 已完成：SQLCipher schema 16 新增严格配置 Vault；十类配置实体支持规范 codec、事务远端应用、依赖排序和墓碑，旧数据库 schema 不迁移。
- 已完成：生产聊天内容运行时组装 ARK、记录加密、outbox、pull、聊天适配器与串行调度器；有效会话的 ChatService 不再使用 LocalOnly 写入器。
- 已完成：安全核心 ABI v8 提供不透明附件密钥、ARK 包装及绑定上传上下文的独立分块加解密；原始 ADK 不进入 Dart。
- 已完成：附件 manifest 使用 ARK 认证的账户记录密文，密文内绑定 attachmentId、uploadId、keyEpoch、完整分块布局、内容摘要、包装 ADK、显示名称和 MIME；外层身份错配、篡改、截断及非法边界均失败关闭。
- 已完成：`kelivo-api/main@02dce9e` 已推送 D1/R2 密文附件六端点、原子配额、幂等状态机及完整 uint32 keyEpoch；未部署。
- 下一步：将配置 Provider 从 SharedPreferences 硬切到 Vault，并把附件 HTTP、本地传输状态、资源落盘与聊天适配器接通。
- 审计关键路径：移动端首账户注册、二维码/恢复文件、撤销设备后的 ARK keyring/epoch 轮换、Android 静默后台同步、D1 硬重建及 Worker 部署尚未完成。
- 已知边界：客户端非空附件仍明确失败关闭，直到附件传输和本地模型闭环后解除。
- 约束：不保留旧数据、旧 payload 或双写兼容路径；业务接线完成并验证前不提前开启内容同步。
