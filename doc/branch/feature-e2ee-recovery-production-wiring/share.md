# 协作摘要

- 跟踪：Issue #49；基线 `feature/e2ee-chat-runtime@e1e97478`。
- 已完成 Android/iOS 账户恢复生产 Runner：恢复授权、两轮 data-rekey、成员替换、设备状态 CAS、成员锚安装、终态会话复验与 checkpoint 两阶段提交均已接入真实实现。
- local -> account 首次绑定保留终态 checkpoint，冷重启后在内容运行时启动前完成复验与删除；桌面端仍不提供注册或恢复入口。
- Native continuation、密钥租约、数据库租约、工作区租约与认证资源均采用显式所有权转移和可重试关闭；连续关闭失败由 Provider 或启动门禁继续持有 owner 并阻止后续会话。
- Provider 瞬时关闭失败重试成功后继续激活账户；连续失败时进入工作区重启状态，不关闭仍由 Runner 使用的 client。
- 既有共享 Native factory 的极端 close-failure owner 风险已另记 Issue #107，不扩大本分支范围。
- 验证通过：改动目标静态分析、`flutter analyze lib test`、Provider 恢复 8 项、Native/授权/数据库/工作区 143 项、v7 checkpoint 5 项、secure-core 依赖分析。
- 已知门禁：根目录 `flutter analyze` 因未改动 path dependency 缺少 `test`/`pigeon` dev 依赖产生 755 项；完整 `flutter test --no-pub` 运行 10 分钟未结束并由工具超时终止。
- 平台验证边界：Android 真机尚未覆盖“持恢复租约时由 `RestartMode.process` 完成冷重启”，代码级安全复核未发现 P0/P1。
