# 协作摘要

- Issue #84 已完成：请求、响应与 Flutter 持久明文日志写入器、设置、查看入口、解析器和存储分类均已硬切删除。
- 历史日志仅通过 #85 的 `KelivoInstallationRootSession.retirePersistentLogs()` 固定操作退役；前台与后台复用各自已打开的受管根会话，不存在 Dart 路径扫描或二次打开根目录。
- 所有工作区先完成旧数据库与同步状态拓扑校验，再执行原生日志退役；原生失败时不先删除其他明文状态。
- 运行时诊断仅保留静态事件，不再输出异常、堆栈、URL、路径、请求正文、凭据、任务名或协议载荷；第三方自由文本 `print` 不再转发到系统日志。
- #85 等价代码提交为 `b4148f0b`、`b0bee160`、`62b15777`、`7560b16c`；Android 挂载别名与 seccomp 修复 `07dd081f` 已等价接入为 `ab002afc`。
- 本任务提交为 `4314735f`、`43995c69`、`f2af44a8`、`4506004a`，应用层受管根接线包含在 `7560b16c`。
- 验证通过：`flutter analyze --no-pub lib integration_test/android_workspace_system_alias_test.dart`；关键 Flutter 回归 182/182；安全核心 Dart 29/29、Windows Rust 89/89、Linux 受管根 21/21；Android x86_64 strict clippy；MCP 152/152；Workmanager Android 单元测试；各路径依赖独立分析。
- API 36 修复 APK 已安装并运行 30 秒且不再触发 syscall 437 `SIGSYS`，但 Flutter/Gradle 驱动宿主未返回集成断言；Windows Debug 构建在 CMake 阶段超时。Apple 原生源码无法在 Windows 编译，`flutter_tts` 与 `workmanager_apple` 没有包内测试目录。
- 复审发现三项发布阻断，正在继续修复：后台冷启动在 `noSession` 前遗漏历史偏好、临时备份、工作区明文状态与持久日志退役；Windows/Linux 偏好删除证明按字符串路径重开文件，存在目录替换竞态；启动、恢复页及 Android/Linux 原生入口仍有动态异常输出。
- 偏好删除证明确定使用最终 ABI20：删除前固定 application-support 根会话，删除后仅从固定根相对打开固定 `shared_preferences.json`；16 MiB 上限内有界读取并结构化解析，文件不存在也必须完成固定根持久屏障与根链复核，任一失败均失败关闭。
- Android `GeneratedPluginRegistrant.java` 是 Flutter 忽略的生成文件，禁止手改；必须通过可重复的生成源或构建配置消除带异常对象的 `Log.e`，并且插件注册失败不得伪装成功。
- 恢复介质页两处动态 `developer.log` 本轮直接静态化；根分支集成时必须保留该结果，并统一其他 E2EE 分支的 ABI20。
- Flutter、PlatformDispatcher 与 Zone 未处理异常改为固定事件且不调用旧动态 handler；三者都会设置非零 `exitCode`，但这只是标记进程最终退出结果，不会立即终止移动端进程。
- Android 构建按变体在 `compileFlutterBuild<Variant>` 完成后、Java 编译前硬化生成 registrant；每个 catch 必须抛固定 `IllegalStateException`，残留 `Log.e` 或数量不一致会阻断构建。
