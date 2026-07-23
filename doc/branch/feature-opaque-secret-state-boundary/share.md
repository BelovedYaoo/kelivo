# OPAQUE 秘密状态接口收口

- 基线：`main@36c206583507332f74ee996d499c6e1b167bddbb`
- 关联：Issue #13（仅复用，不在本分支操作 Issue）
- 目标：保留协议线对象的公开字节接口，将客户端注册、客户端登录、服务端登录状态收口为仅限同一 Rust 进程传递的不透明类型。
- 边界：仅修改 `dependencies/kelivo_secure_core/protocol`；不接入 FFI/API，不实现状态密封，不暴露 OPAQUE export key。
- 完成：
  - 三类秘密状态直接持有 `opaque-ke` 的零化类型，生产流程以消费式不透明值传递。
  - 秘密状态线格式编解码仅保留为 `cfg(test)` 私有辅助；公开线对象接口与固定摘要保持不变。
  - 新增源结构断言，阻止秘密状态重新套用公开 `from_bytes/as_bytes` 接口。
- 验证：
  - `cargo fmt --all -- --check`
  - `cargo test --locked`（8 项通过）
  - `cargo clippy --locked --all-targets -- -D warnings`
  - `cargo check --locked --target wasm32-unknown-unknown`
  - `cargo build --locked --target wasm32-unknown-unknown`
