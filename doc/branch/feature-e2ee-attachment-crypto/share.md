# E2EE 附件安全核心

- 已实现：ABI v8 附件数据密钥不透明句柄、ARK 包装/解包、XChaCha20-Poly1305 独立分块和 Dart 布局接口。
- 契约：包装绑定用户、附件与正 `uint32` epoch；分块另绑定服务端 `uploadId`、序号、块数、总长度和本块长度。完整块信封严格不超过 4 MiB，最多 1000 块。
- 安全性：句柄幂等关闭且关闭后失败；认证失败不写明文；临时密钥和 Dart FFI 副本均清零；无原始附件密钥进入 Dart。
- 验证：`flutter analyze`、`flutter test`、协议层与 native 层 `cargo test --all-targets`、两层 `cargo clippy --all-targets` 均通过。native Clippy 仅有两条既有 `record_*` 参数数量警告。
- 边界：未接入 HTTP、数据库、主程序或聊天适配器。当前服务端 epoch 上限仍为正 `int32`，与安全核心正 `uint32` 契约需由集成分支统一。
