# fix/e2ee-release-gates

- 范围：Windows 与 Android 的 E2EE CI/发布门禁，仅修改 workflow 和必要工具脚本。
- 验收：Flutter 3.44.1、Android Rust 三架构与 Workmanager JVM 测试、Windows 隔离安全核心测试、FFI 生成漂移检查均进入 CI。
- 禁止：不修改业务或 Native 实现，不访问默认安全槽，不部署、不推送。
- Issue：#13 覆盖跨平台硬门槛，#81 约束默认安全槽隔离；无需重复建单。
- 状态：已接入 FFI 漂移检查，并拆分普通测试与 Windows 隔离安全核心测试。
