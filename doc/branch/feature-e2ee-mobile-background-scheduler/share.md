# 移动端 E2EE 静默后台调度

## Mini Control Contract

- Primary Setpoint：Android/iOS 由系统静默唤醒后，只运行一次既有 `E2eeBackgroundSyncRunner`，并可在进程重启后从持久会话恢复。
- Acceptance：登录且开启同步时注册；登出、暂停或无有效安全状态时取消并失败关闭；并发回调只执行一次；Android 定向构建和相关测试通过；iOS 通道与 BGTask 配置完成静态校验。
- Guardrails：不使用 UI Provider，不显示或生成通知，不改变桌面入口，不绕过成员清单安全预检，不伪造成功，不吞掉失败。
- Boundary：`lib/core/services/sync/**`、移动端应用生命周期接线、`android/app/**`、`ios/Runner/**`、依赖声明及既有同步测试。
- Risks：后台 isolate 的插件注册与持久存储初始化；系统取消信号及时传入 runner；Android/iOS 调度语义差异导致重复或错过执行。

## 最小场景集

- 正常路径：有效持久会话且同步启用，系统回调执行一次 runner 并正确结束平台任务。
- 边界输入：重复注册、并发回调、进程重启、系统预算即将耗尽，均保持幂等与有界退出。
- 失败路径：无会话、已登出、同步暂停、认证撤销、安全状态未验证、插件初始化失败时不运行同步且不报告成功。
- 状态转换：登录/启用时注册，暂停/登出时取消，恢复启用后重新注册；终止认证清理后后续回调不再执行。

## 进度

- Android/iOS 系统调度、登录状态串行注册、进程内回调去重和无通知静默执行已完成；iOS 最低版本为 14。
- 单次执行的工作区获取、内容初始化、网络、终止认证和资源清理均受同一单调截止约束；截止或取消后最多共享 2 秒关闭宽限，迟到所有权仍会异步释放。
- Android `onStopped` 与 iOS expiration 会先通知 Dart；4 秒后无条件释放平台任务。iOS 平台完成不再依赖主线程或 `destroyContext()` 返回，迟到的通道回调不会重新启动任务。
- 已删除公开 capability 与生产 Runner 构造入口。生产 Runner 只能由私有已验证内容工厂创建；schema 21 尚未提供原子验证绑定时，注册会在 Workmanager 初始化前明确失败，历史任务会取消自身并返回失败，测试 Host 无法注入生产回调。
- `BGTaskScheduler.submit` 与 pending request 校验、Android 唯一周期任务、iOS 独立 BGAppRefreshTask 标识及 15 分钟最早周期均已接通。
- 验证完成：根目录定向 `flutter analyze`、四个本地 Workmanager 包各自 `flutter analyze lib`、专项测试 79/79、Android debug APK 构建均通过。Windows 无法编译 Swift，iOS 仍需 macOS CI 或真机验证。
- Issue #56 保持开启，等待 schema 21 提供设备密钥封存、ARK 验签、会话世代与认证世代的私有原子绑定工厂后才能启用生产后台同步；Kotlin 未来兼容警告由 #60 跟踪。
