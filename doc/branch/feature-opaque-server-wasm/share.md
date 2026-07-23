# OPAQUE 服务端 Wasm 分支协作摘要

- 目标：实现可供 Cloudflare Workers 调用的 OPAQUE 服务端 raw Wasm 接口。
- 安全边界：`ServerLoginState` 只能在 Rust 内部加密封装；Wasm、TypeScript、D1 均不得接触裸状态。
- 已完成：176 字节 XChaCha20-Poly1305 continuation、固定 48 字节 AAD、注册与登录四操作 raw ABI、敏感缓冲区单次消费及归零、未知账户固定响应、统一认证失败。
- 产物：release Wasm 为 144909 字节，SHA-256 为 `71CC3A2A71C836B4570033F1EAAAC4B50DD751EDB23C976D33E802CDC290DB45`；零 imports，导出严格限制为九个 ABI 函数、memory 与两个 Rust 内存边界全局。
- 验证：协议 17 个单测及 3 个 doctest、Wasm 10 个单测、native 34 个单测、安全核心 Dart 9 个测试、根应用 1429 个测试全部通过；格式、Clippy、Wasm release 与 Node ABI 烟测通过。
- 独立审查：无密码学、功能或合并阻断项。
- 后续边界：API 四步 OPAQUE 路由、D1 一次性状态接线、Workers CPU 基准与部署不属于本分支。
- 关联 Issue：app #13、API #5。
