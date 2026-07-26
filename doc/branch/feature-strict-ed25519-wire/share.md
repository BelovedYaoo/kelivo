# Ed25519 严格验签一致性

- 已修复 Issue #32：设备公钥 A 与签名 R 均要求规范编码、非小阶且属于素数阶子群，再执行 dalek 2.2 严格验签。
- CCTV #50 与 #7 固定向量锁定混合阶 A/R 拒绝行为；标准 KDPF/KAEK 固定向量和生成签名保持通过。
- 协议 crate 三组测试与 Clippy、native 测试与 Clippy 均通过。
