# feature/e2ee-foundation 协作摘要

- 关联 Issue：BelovedYaoo/kelivo#13。
- 分支基线：`main@6bead2d2`；本分支不得改变当前 1.1.17 发布产物或明文同步兼容路径。
- 当前阶段只验证硬门槛：Windows/Android SQLCipher、Linux 边界、平台安全存储、Rust 安全核心 ABI、Workers/WASM OPAQUE、混合后量子算法和二维码容量。
- 密码算法只允许由共享 Rust 安全核心实现；Dart、TypeScript 与平台壳层只负责版本化调用和密钥句柄，不得持久化长期明文密钥。
- 任一平台或协议验证失败均 fail-closed，不得自动回退到明文 SQLite、弱算法或服务器可解密方案。
- 当前尚未完成任何 E2EE 产品集成，不得在用户文案或发布说明中声称已具备端到端加密。
