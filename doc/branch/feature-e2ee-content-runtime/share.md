# E2EE 内容运行时

## 目标

- 实现生产聊天 E2EE 内容运行时，并实现 `CloudSyncContentRuntime` 与 `SyncWriteExecutor`。
- 同步周期固定为有界 pull catch-up、seal、flush、final pull，保持串行与唤醒合并。
- 初始化只对本地密码学、数据库和生命周期错误失败关闭；离线网络失败异步重试。

## 边界

- 不修改 `lib/main.dart`。
- 不修改配置同步或附件实现。
- 不保留旧明文数据或兼容路径。
- transport 会话必须显式携带 `deviceKeyVersion`；主分支 Provider 的会话重建遗漏另行处理。

## 进度

- 已实现 `E2eeChatContentRuntime`，真实组装 ChatService、ARK 租约、record cipher/state codec、数据库租约、outbox、聊天适配器、pull coordinator 与显式令牌 transport。
- 已实现有界同步周期和串行调度器：pull catch-up、seal、flush、final pull；30 秒轮询、指数退避、epoch 暂停和唤醒合并。
- 本地写等待运行时初始化，事务成功后才唤醒调度；关闭先封闭写入、取消调度并强制关闭 HTTP，再等待周期、本地写与 ChatService，最后按实际所有权清理密码学和数据库资源。
- ChatService 绑定会核对共享数据库网关和写入执行器身份，错误装配失败关闭。
- 已修复周期完成边界上的唤醒竞态，并由专门用例覆盖。

## 验证

- 定向 `flutter analyze`：无问题。
- `flutter test test/core/providers/cloud_sync_provider_content_gate_test.dart --plain-name E2EE --concurrency=1`：9 项通过。
- 完整 `cloud_sync_provider_content_gate_test.dart`：28 项通过；新增竞态用例后将于变基后重跑完整文件。

## 剩余边界

- 本分支不接入 `lib/main.dart`，由主分支后续创建独占 CloudSyncClient、构造运行时、构造 ChatService 并完成绑定。
- 配置 Vault 和附件数据面不属于本分支。
