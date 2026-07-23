# feature/e2ee-opaque-protocol-poc 完成摘要

- 基线：`main@ec14e5e89f550d369189d92c246f48085ed0aa2c`。
- 范围：仅新增 `dependencies/kelivo_secure_core/protocol` 纯 Rust PoC；未改 FFI、Flutter、API 或部署。
- 协议：固定 `opaque-ke 4.0.1`，采用 Ristretto255、TripleDh、SHA-512 与显式 Argon2id（64 MiB、t=3、p=4）。
- 线格式：`KOPA` 魔数、版本/套件/密码配置/对象类型/标志/长度固定头；所有 11 类协议对象严格校验并使用归零缓冲区。
- 密钥边界：生产公开接口不暴露底层 suite 或 `export_key`，不存在 ARK/root wrapping 入口；客户端与服务端会话密钥均由 `Zeroizing` 持有。
- 验收：主机 7 项测试通过，包含 RFC 9807 两组真实向量、一组假账户向量逐字节校验、全对象固定 RNG 线格式摘要，以及随机源失败关闭；严格 Clippy 通过；`wasm32-unknown-unknown` 构建通过。
- 后续集成约束：Dart FFI 不得把 `ClientRegistrationState`、`ClientLoginState`、`ServerLoginState` 作为可持久化明文字节暴露；网络层必须统一未知账户与错误密码的对外错误。
- 未覆盖：PoC 尚未接入平台安全存储、FFI、Flutter 或服务端；WASM 仅完成编译与失败关闭逻辑验证，未做浏览器运行时与独立密码学/侧信道审计。
