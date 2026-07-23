# OPAQUE 服务端 Wasm 分支协作摘要

- 目标：实现可供 Cloudflare Workers 调用的 OPAQUE 服务端 raw Wasm 接口。
- 安全边界：`ServerLoginState` 只能在 Rust 内部加密封装；Wasm、TypeScript、D1 均不得接触裸状态。
- 接口范围：注册 start/finish、登录 start/finish；不导出 session key 或 export key。
- 已完成协议切片：固定 176 字节、版本 1 的 XChaCha20-Poly1305 continuation；32 字节密封密钥在析构时归零，调用方 AAD 被认证绑定。
- 公共接口：`server_login_start_sealed` 只返回响应与密封 continuation；`server_login_finish_sealed` 只返回认证成功或错误。
- 验证：协议测试 11/11、Clippy `-D warnings`、`wasm32-unknown-unknown --all-targets` 检查及格式化检查通过。
- 后续边界：Wasm ABI 尚未包含在本提交；continuation 单次消费与过期由 API/D1 状态层实现。
- 关联 Issue：app #13、API #5。
