# 协作状态

- 基线：`feature/e2ee-chat-runtime@2e97a9a8eefdea51193d7b9c47bf739ed4e3e384`。
- 目标：为 App #49 实现 ABI19 恢复挑战证明与 replacement/resume 准备事务，秘密仅存在于 Native。
- 当前：协议层与 Native execution 已完成。协议严格解析并绑定 316 字节 challenge、100 字节 HPKE sealed nonce、108 字节 proof transcript，并能准备 resume/replacement 提交；Native 原子执行拥有恢复 ARK，缓存相同 prepare 输入，任何上下文或认证代数错配都会销毁 execution 与 ARK。
- 已验证：protocol 完整测试（66 个单测、1 个 doctest、4 个 compile-fail）通过；protocol/native `cargo clippy --all-targets --all-features -- -D warnings` 通过；Native 账户恢复端到端测试（1/1）通过。
- 已知验证边界：当前 Windows 环境运行 Native 全量测试时，既有 `installation_root_wipe::windows` 测试以 `STATUS_STACK_BUFFER_OVERRUN` 中止；单线程仍可复现，未影响账户恢复聚焦测试。
- 待完成：ABI 19 C header、ffigen、Dart API/应用适配、跨目标 Clippy 与完整 Flutter 验证。
- 边界：不访问默认安全槽、不部署；Windows/Linux/macOS 恢复执行能力保持 Unsupported。
