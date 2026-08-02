# fix/e2ee-release-gates

- 范围：Windows 与 Android 的 E2EE CI/发布门禁，仅修改 workflow 和必要工具脚本。
- 验收：Flutter 3.44.1、Android Rust 三架构与 Workmanager JVM 测试、Windows 隔离安全核心测试、FFI 生成漂移检查均进入 CI。
- 禁止：不修改业务或 Native 实现，不访问默认安全槽，不部署、不推送。
- Issue：#13 覆盖跨平台硬门槛，#81 约束默认安全槽隔离，#63 跟踪保留脚本的既有 ShellCheck 基线；无需重复建单。
- 完成：仅保留 3.44.1 发布工作流；Windows/Android 构建通过共享 FFI 门禁，Release 等待所有已选平台成功后一次发布；iOS、macOS、Linux 仅允许非发布验证。
- 验证：FFI 重生成无漂移；Workmanager Android JVM 测试通过；Windows 根集成 173 项与安全核心包 35 项隔离测试通过；YAML 及 Action 结构检查通过。
- 边界：未执行 Android APK 完整签名构建；iOS、macOS、Linux 不属于当前可发布平台。
