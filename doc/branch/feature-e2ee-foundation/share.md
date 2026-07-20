# feature/e2ee-foundation 协作摘要

- 关联 Issue：BelovedYaoo/kelivo#13。
- 合规跟踪：BelovedYaoo/kelivo#14，公开发行前补齐 SQLCipher 与 OpenSSL 的用户可访问许可证声明。
- 平台跟踪：BelovedYaoo/kelivo#15 补齐 Linux 运行门禁；BelovedYaoo/kelivo#16 处理既有插件的 Cargokit 依赖。
- 发布跟踪：BelovedYaoo/kelivo#17 要求 Android Release 缺少签名配置时立即失败。
- 分支基线：`main@6bead2d2`；本分支不得改变当前 1.1.17 发布产物或明文同步兼容路径。
- 当前阶段只验证硬门槛：Windows/Android SQLCipher、Linux 边界、平台安全存储、Rust 安全核心 ABI、Workers/WASM OPAQUE、混合后量子算法和二维码容量。
- 密码算法只允许由共享 Rust 安全核心实现；Dart、TypeScript 与平台壳层只负责版本化调用和密钥句柄，不得持久化长期明文密钥。
- 任一平台或协议验证失败均 fail-closed，不得自动回退到明文 SQLite、弱算法或服务器可解密方案。
- 当前尚未完成任何 E2EE 产品集成，不得在用户文案或发布说明中声称已具备端到端加密。
- SQLCipher 原型复用 `integration_test/database_platform_capabilities_test.dart`；普通 SQLite 构建已按预期红灯失败，错误为 `sqlcipher_unavailable`。
- 原型固定 `sqlite3 3.4.0`，由官方 Native Assets hook 选择 SQLCipher；生产接入仍须统一收口 Drift、raw sqlite、快照、恢复与 ATTACH 的密钥路径。
- Windows 与 Android 实机门禁均确认 SQLCipher 4.17.0 community、SQLite 3.53.3；错误密钥、无密钥、明文头、WAL 明文、FTS5、在线备份和锁竞争均通过预期断言。
- Windows Release 和已签名 Android Release 构建通过；Android 三个 ABI 的 SQLCipher LOAD 段均为 16 KiB 对齐。Linux 尚未实机验证，不得据此声称全平台完成。
- 已新增 `dependencies/kelivo_secure_core`：官方 Native Assets Build Hook 直接调用锁定的 Rust 1.91.0/Cargo，不引入桥接层；C ABI v1 固定 32 字节能力结构并仅导出五个白名单函数，调用方必须提供输出缓冲区长度。
- Dart 只暴露能力对象和不透明句柄；句柄关闭使用 open/closing/closed 状态机阻止重复或并发释放。Windows 报告 DPAPI 后端及密钥槽位/后台能力，其他平台保持零能力并明确返回“不支持平台”，缺失后端时 fail-closed。
- Windows Release 最终目录只有一个 x64 安全核心 DLL且恰好五个导出；Windows 与 Android x64 已实际加载并通过 ABI 门禁。
- 已签名 Android Release 包含 arm64-v8a、armeabi-v7a、x86_64 三种正确架构，每个库恰好五个导出且所有 ELF LOAD 段均为 16 KiB 对齐，APK 也通过 16 KiB ZIP 对齐。Android arm/arm64 与 Linux 尚未运行验证。
- Windows DPAPI 槽位 v1 已完成：固定 `%LOCALAPPDATA%/Kelivo/secure-core/v1/slots`，使用 CNG 随机数、当前用户作用域和禁止 UI 的 DPAPI、槽位 ID 熵绑定、原子不覆盖写入、堆上零化密钥与进程内永久不复用句柄；Rust 8 项测试、Windows 集成探针和 Release 原生门禁均通过。
