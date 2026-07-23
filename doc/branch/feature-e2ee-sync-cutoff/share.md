# feature/e2ee-sync-cutoff 完成摘要

- 旧内容同步数据面已硬切关闭：生产启动不再初始化旧 Hive、`CloudSyncStore` 或 `SyncWriteJournal`，九个领域组件统一使用 `LocalOnlySyncWriteExecutor`；账号、设备和退出登录控制面继续可用。
- 启动在业务数据库打开前枚举匿名及全部账号工作区。所有目录、链接、SQLite/Hive 和同步状态拓扑先整批预检，全部通过后才删除；任一歧义均失败关闭。
- 三个旧 Hive box 的 `.hive/.hivec/.lock` 文件族通过校验回执链退役；同前缀未知文件拒绝处理。`cloud_sync_state_v1` 文件族同样支持中断恢复并拒绝未知拓扑。
- Windows 原生持久化原语使用扩展长度路径，超过 260 字符的文件、目录和原子重命名已通过回归测试；UNC/SMB 仍保留为后续平台验收边界。
- 聊天、导入、恢复、删除和清空操作均保持本地语义，且不再生成旧 v2 完整重扫请求。

## 验证

- `flutter gen-l10n`：通过，`desiredFileName.txt` 为 `{}`。
- `flutter analyze --no-pub`：通过。
- `flutter test --no-pub`：1578 项通过，19 项按既有平台条件跳过，0 项失败。
- `flutter build windows --release`：通过；首轮 MSBuild 并发锁后使用降并发开关重试成功。
- `flutter build apk --release`：构建通过；额外签名校验失败，当前 APK 不能作为可发布签名产物，需单独修复并复验。

## 后续边界

- 旧同步数据面源码仍留在仓库但没有生产调用链；接入 v3 客户端时应直接删除，不能重新启用。
- 多工作区清理不是跨目录文件系统事务；正常崩溃可由持久化标记恢复，同权限恶意本地进程的 TOCTOU 不在当前服务器运营者威胁模型内。
- Android Release 签名链未通过独立校验；该发布问题不影响本次同步硬切代码合入，但在交付 APK 前必须修复。
