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

- 已确认 Issue #56 为唯一跟踪项，固定基线为 `d1ae65e3`。
- 已将安全门升级为绑定账号、设备、会话世代、认证世代、密钥世代和成员清单摘要的不可变 capability；Runner 在工作区租约内再次读取并逐字段复核，同时校验当前会话账号、设备和密钥世代。
- 生产 gate 不再固定返回 `false`，而是保留严格持久可信读取接口；当前 schema 21 读取器尚未接线时明确抛出依赖缺失，且不会永久取消系统周期任务。
- 20 秒从首次可信状态读取前开始统一核算，工作区、内容初始化、网络和清理超过截止均不向平台报告成功；系统取消通过同一 cancellation signal 传入 Runner。
- 已本地化官方 Workmanager 四个包并用 Pigeon 源生成取消协议：Android `onStopped` 与 iOS expiration 均通知 Dart，等待任务 Future 尽力执行 finally 后再销毁引擎或完成系统任务。
- iOS `BGTaskScheduler.submit` 错误现在直接返回 Dart；注册完成后还会查询 pending request，二者任一失败均视为注册失败；周期重提交失败会明确完成为失败。
- Android 使用唯一周期 WorkRequest，iOS 使用独立 BGAppRefreshTask 标识；均为 15 分钟最早周期，不接通知。
- 前台生命周期仅观察 `CloudSyncProvider` 的登录与内容就绪状态并串行注册/取消；headless 回调不导入或构造任何 Provider。
- 系统回调经进程内去重后只调用一次 `E2eeBackgroundSyncRunner`；无会话或终止认证会取消后续任务，未知任务和未验证安全状态失败关闭。
- iOS 最低版本已硬切到 14，Podfile 与全部 Runner Xcode deployment target 一致；Info.plist、AppDelegate 标识和插件注册静态检查通过。Windows 无法执行 iOS 编译/真机唤醒。
- 根定向 analyze 与四个本地依赖各自 analyze 无问题；内容门禁 76/76 通过；Android debug APK 原生构建成功。全仓 analyze 精确保留既有 #33 的 736 条 `mcp_client` 测试错误，Workmanager 无新增问题。
- 剩余接线：主线 schema 21 必须提供设备密钥封存且完成 ARK 验签的持久 capability 读取器；Android/iOS 仍需真机验证系统回收、重启和 expiration/onStopped 的清理时序。
- Android 构建发现的未来 Built-in Kotlin 兼容警告已单独记录为 #60，本分支不扩展处理。
