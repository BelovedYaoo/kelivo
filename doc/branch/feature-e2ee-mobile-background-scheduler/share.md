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
- 已接入 `workmanager 0.9.0+3`：Android 使用唯一周期 WorkRequest，iOS 使用独立 BGAppRefreshTask 标识；均为 15 分钟最早周期、联网/低电量/低存储约束、20 秒 runner 截止，不接通知。
- 前台生命周期仅观察 `CloudSyncProvider` 的登录与内容就绪状态并串行注册/取消；headless 回调不导入或构造任何 Provider。
- 系统回调经进程内去重后只调用一次 `E2eeBackgroundSyncRunner`；无会话或终止认证会取消后续任务，未知任务和未验证安全状态失败关闭。
- 生产安全门当前明确返回未验证：必须由主分支 schema 21 的设备密钥封存锚点接入后才能放行，禁止使用服务端字段或普通偏好替代。
- iOS 最低版本已硬切到 14，Podfile 与全部 Runner Xcode deployment target 一致；Info.plist、AppDelegate 标识和插件注册静态检查通过。Windows 无法执行 iOS 编译/真机唤醒。
- 定向 analyze 无问题；内容门禁 71/71 通过；Android debug APK 构建成功，最终 Manifest 已包含 WorkManager JobService、启动初始化和重启恢复组件。全仓库 analyze 仍仅被既有 #33 的 `mcp_client` 测试缺少 `package:test` 阻断。
- Android 构建发现的未来 Built-in Kotlin 兼容警告已单独记录为 #60，本分支不扩展处理。
