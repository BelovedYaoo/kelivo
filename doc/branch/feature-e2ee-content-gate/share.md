# 工作摘要

- 云同步 Provider 已硬切为唯一公开构造入口 `CloudSyncProvider.controlPlaneOnly`，不接收聊天、配置、旧 `CloudSyncStore` 或 `SyncWriteJournal`。
- 新增账户控制面接口，Provider 仅能登录、恢复会话、列出设备和撤销设备；同步、暂停与冲突公开动作固定拒绝执行，不创建定时器或生命周期观察者。
- 云同步页面隐藏同步状态、暂停、立即同步与冲突区，显示端到端加密升级期间仅本机保存的提示，账户和设备管理保持可用。
- 四个 ARB 已同步，生成的本地化代码由 `flutter gen-l10n` 更新。
- `lib/main.dart` 仅将 Provider 构造切到 `controlPlaneOnly`；旧状态库启动创建和旧写执行器由集成分支统一退役。

## 验证

- `flutter gen-l10n`
- `flutter test --no-pub test/core/providers/cloud_sync_provider_content_gate_test.dart`：6 项通过
- `flutter test --no-pub test/core/services/sync/cloud_sync_client_protocol_test.dart`：9 项通过
- `flutter analyze --no-pub lib test`：通过
- `dart analyze` 本次改动的 Dart 文件：通过
- `desiredFileName.txt` 保持 `{}`。

整仓 `flutter analyze --no-pub` 被未修改的 `dependencies/mcp_client` 测试环境缺少 `package:test` 阻塞；根项目 `lib` 与 `test` 范围无问题。
