# 恢复介质安全核心协作摘要

- Primary Setpoint：在安全核心 ABI v15 实现固定线格式的恢复 capsule、独立口令加密恢复介质与一次性恢复句柄，不接 UI、Provider 或服务端。
- Acceptance：protocol/native 测试、严格 Clippy、依赖 Flutter 分析与现有测试、根定向协议测试通过；Rust/header/ffigen/Dart ABI 与常量一致。
- Guardrails：ARK、恢复私钥和恢复介质明文不得进入 Dart；无无口令、兼容或降级路径；失败输出清零，capsule 打开失败保留 import 句柄，成功原子消费。
- Boundary：`dependencies/kelivo_secure_core` 的 protocol/native/C ABI/ffigen/Dart 与既有测试，以及现有 Issue #49；不修改应用业务接线。
- Risks：genesis 清单必须由原生同时验证线结构、账户信任签名和恢复公钥绑定；Argon2id 峰值资源需在移动端目标编译层验证；句柄成功消费与失败恢复必须无竞态。
- 场景：覆盖生成、导出、导入、当前与 epoch 2 以后 capsule；口令 12 scalar/128 UTF-8 字节边界；错误口令/origin/长度/篡改/genesis/capsule；句柄关闭、并发关闭、失败重试、成功消费与输出清零。
- 已确认：三步流程为恢复身份生成 -> capsule 封装 -> genesis 签名后导出 media，用于解除 capsule 摘要与 genesis 的环依赖。
