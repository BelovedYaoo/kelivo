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
- 已合入明文同步状态退役与内容同步门禁：应用不再初始化旧 Hive、`CloudSyncStore` 或 `SyncWriteJournal`，领域写入统一使用 `LocalOnlySyncWriteExecutor`，云同步只保留账号和设备控制面。
- 启动阶段会在任何业务数据库打开前枚举匿名及全部账号工作区；先整批校验目录、链接、SQLite/Hive/同步状态拓扑，再清理所有明文数据库与同步状态。任一工作区存在歧义时整批失败关闭，不会先部分删除。
- 三个旧 Hive box 的 `.hive/.hivec/.lock` 文件族均纳入回执链清理；同 box 前缀的未知文件失败关闭，避免压缩中断遗留完整明文帧，Issue #27 等完整验证后关闭。
- Windows 原生持久化调用已使用扩展长度路径；超过 260 字符的账号目录可完成文件/目录同步与原子重命名，Issue #26 等完整验证后关闭。
- 旧 Hive 退役与账号工作区相关测试共 54 项通过；根仓及变更文件 `flutter analyze --no-pub` 通过。
