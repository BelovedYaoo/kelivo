# feature/e2ee-sync-cutoff 协作记录

## Mini Control Contract

- Primary Setpoint：在完整密文同步协议接入前，硬切销毁旧明文同步状态，并确保聊天、配置、供应商密钥和附件内容不会再次写入明文 outbox 或上传到服务器。
- Acceptance：旧 `cloud_sync_state_v1.hive` 文件族可崩溃恢复地删除；所有领域写入使用仅本地执行器；内容同步、冲突与定时任务 fail-closed；账号登录、退出和设备管理仍可用；相关测试、`flutter analyze --no-pub` 与全仓测试通过。
- Guardrails：保留账号工作区的 `session-v2` 与加密 `token-v1-*.bin`；不伪装同步成功；不引入明文或弱算法回退；新增文案同步四个 ARB；不部署服务端变更。
- Boundary：合并明文同步状态退役与内容 Provider 门禁两个独立提交，并只在 `lib/main.dart` 增加必要启动顺序和依赖注入。
- Risks：直接调用 `CloudSyncStore.runWithDefaultRescanWrite` 的旧入口仍可能留下非内容同步元数据；Provider 的登录、生命周期和错误恢复路径可能间接启动数据面；硬切文件族必须拒绝目录、链接和未知拓扑。

## 进度

- SQLCipher 生产链路已合入 `main@48e1a1b1`，Issue #24 已关闭。
- 已退役聊天、导入和恢复路径对 `CloudSyncStore.runWithDefaultRescanWrite` 的生产调用，并删除仅服务旧重扫协议的测试注入接口。
- 相关聊天、Cherry/Chatbox 导入和本地备份恢复测试通过；这些路径在成功与失败时都不会创建 `cloud_sync_state_v1` 文件族。
- 子分支 `feature/e2ee-sync-state-retirement` 已完成，`feature/e2ee-content-gate` 正在收口，随后以独立提交集成本分支。
