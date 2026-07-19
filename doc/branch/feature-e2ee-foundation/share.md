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
