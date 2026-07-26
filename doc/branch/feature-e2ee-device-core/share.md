# E2EE 设备安全核心

- 目标：在 Rust 安全核心暴露设备身份、ARK 与 KDPF/KAEK 的不透明句柄 ABI，推进 Issue #13。
- 约束：Dart 不得读取设备私钥、ARK 或恢复密钥；跨 FFI 只传版本化公开材料、密文信封、证明与不透明句柄。
- 生命周期：所有句柄必须显式关闭，失败路径清零临时秘密；持久化只保存平台安全存储可封装的版本化密文状态。
- 平台优先级：Windows 与 Android 必须可构建验证，Linux 次之；本分支不提前修改登录 UI 或同步业务层。
- 当前进度：协议层已完成 KDPF kind=3、原始载荷内部哈希、配对 HKDF/HMAC 信任根、设备身份/ARK 秘密类型及 188 字节两态状态密封；已覆盖配对字段替换矩阵，并保证状态明文元数据只在 AEAD 认证后解析；Native ABI v4 正在实现。
- 配对信任顺序：目标端从本地 create transcript 重建 KDPF，先验证 32 字节 authenticator，再验证 KDPF、KAEK，最后 HPKE 解封 ARK。
- Native ABI v4 已实现第 5 类一次性 PendingPairing 句柄：start 在 Rust 内生成 pairingId/secret/hash，bind 校验并锁定服务端响应，accept 通过墙钟与单调时钟双门禁，失败归还、成功原子消费并清零；目标端不再接收 Dart 回传的 secret 或目标 transcript。
- Native 验证：Windows 下 `cargo test --locked` 38 项通过，`cargo clippy --locked --all-targets -- -D warnings` 与 `cargo build --release --locked` 通过；下一步生成 FFI binding 并实现 Dart 严格生命周期封装。
- 状态布局：12 字节规范头 + 40 字节认证元数据 + 24 字节 nonce + 96 字节秘密密文 + 16 字节 tag；pending 不含 ARK，完整态绑定 deviceId/keyVersion/userId/keyEpoch。
