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

## 结果

- 已补齐结算后截止的所有权转移、迟到内容取得结算屏障、严格 `runtime -> account -> workspace` 单次释放；有界清理失败会在 Runner 返回前同步调用现有错误上报，密钥世代阻塞会向平台返回失败。
- Android 使用独立调度线程保证取消后 4 秒内结算平台任务；iOS Operation 与 legacy fetch 共用单一 `pending/executing/terminal` 生命周期状态机，各自保证 4 秒硬终态，平台完成不再等待主线程引擎销毁。iOS 最低版本保持 14。
- 生产 Runner 工厂继续返回 `null`；schema 21 原子验证绑定完成前不启用真实后台内容同步，Issue #56 保持开启。
- 验证通过：专项测试 84/84、`flutter analyze lib`、改动测试文件分析、四个 Workmanager 包分析、Android debug APK 构建和原生静态接线契约。根目录全量分析仍受既有 #33 影响；根目录全量测试命中既有 #53 挂起后已停止并清理残留进程。Windows 无法执行 Xcode/iOS 生命周期竞态或实机构建，静态字符串断言不替代该覆盖，仍需 macOS CI 或真机验证。
