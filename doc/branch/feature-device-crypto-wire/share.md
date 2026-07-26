# 设备密码学线格式

- 目标：冻结设备 Ed25519/X25519 身份、私钥持有证明和定向 ARK 密钥信封的唯一 v1 线格式。
- 约束：使用标准 HPKE，不让服务器接触 ARK 或设备私钥；注册和登录证明必须绑定 OPAQUE attempt。
- 已完成：KDPF v1 固定 224 字节消息、Ed25519 严格签名验证、服务端预期字段全量比对、UUIDv4/弱公钥/低阶 X25519 拒绝；旧 attempt 的有效签名也会拒绝。
- 已完成：KAEK v1 固定 336 字节信封，使用 RFC 9180 base mode X25519/HKDF-SHA256/ChaCha20Poly1305；头、三类 ID、epoch 和双方四把公钥同时进入 HPKE info、AAD 与 issuer 签名。
- 已完成：ARK、Ed25519 私钥种子、X25519 私钥和临时明文缓冲区归零；公开接口只接受或返回定长类型。
- 已完成：`device-crypto` 显式统一启用 `x25519-dalek 3.0.0/zeroize`，并以编译期 trait 断言证明 `StaticSecret` 与 `SharedSecret` 实现 `ZeroizeOnDrop`。
- 已完成：`device-crypto` 是可选特性；native 默认启用，server_wasm 的 `default-features = false` 不编入 HPKE/Ed25519/X25519。
- 跨语言向量：KDPF 224B SHA-256 `1BF55893F981A8439228EABD95DCA74D5D08BE93352F69913F59736187A24819`；签名 64B SHA-256 `64B46EF1DBE802524A8EF78EC1DF6F588095B9C02F8BC82ACA2204A578E66C67`；KAEK 336B SHA-256 `449BDD5FACC0ADE9C66052441444C0EE0D2F7E1650FF292C4A9C2A28448912F7`。完整十六进制位于协议内联测试。
- 验证：protocol 默认 31 个、无默认特性 17 个、无默认特性加 device-crypto 31 个单测均通过；对应 doctest 与三组 Clippy `-D warnings` 通过；native 34 个、server_wasm 10 个测试通过；禁用特性与 server_wasm 依赖树均无设备密码学依赖。
- Wasm：release 产物 144909 字节，SHA-256 `B2DB00BE416FD7D4CA717E47B4DA98AFC4C898226D488601263B0B8B48387BEB`，零 imports，导出列表未变化。
- 后续对接：start 必须生成 32B challenge 并保存到可信 attempt；finish 从该 attempt 重建全部 KDPF 预期字段、检查过期并一次性消费。无 KAEK 信封时 envelope hash 唯一使用 SHA-256(empty)。
