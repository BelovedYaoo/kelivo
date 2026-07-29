# 协作摘要

- 目标：沿用 Issue #51，在安全核心增加成员设备间 ARK 轮换信封原语；不修改应用 Provider、服务端、成员清单、恢复 capsule 或兼容路径。
- 输入边界：签发设备 identity 句柄、当前不透明 ARK 句柄、严格 UUIDv4 的用户与设备标识、完整正 `uint32` epoch，以及 32 字节签发/目标公开键。
- 输出边界：封装只返回固定 336 字节 ARK envelope；开启只返回新的不透明 ARK 句柄，原始 ARK 与设备私钥不得进入 Dart。
- 完成：新增独立 seal/open C ABI 与 `KelivoAccountRootKeyEnvelope` 强类型 Dart API；复用现有 HPKE/Ed25519 信封算法，目标 identity 严格核对双方公钥和完整绑定后才注册新 ARK 句柄。
- 完成：ABI 硬切 v9，header、Rust 导出、ffigen 生成绑定、能力门禁与测试已同步；没有旧 ABI 双路、Provider、服务端、成员清单或恢复实现。
- 安全：seal 失败清零可写输出，open 失败重置句柄；Dart 操作期间占用句柄并拒绝并发关闭，原生句柄类型混淆和关闭后使用均失败关闭；原始 ARK 与私钥始终只在 Rust 内。
- 验证：协议 Rust 全量 39/39、文档测试 5/5；原生 Rust 全量 46/46、轮换定向 2/2；依赖 Flutter 全量 17/17；`flutter analyze` 通过；协议严格 clippy 通过，原生严格 clippy 仅被两个既有多参数函数拦截，放行该既有 lint 后通过。
- 环境：`R:\Temp` 空间不足已登记 Issue #57；验证仅对当前进程改用 `%LOCALAPPDATA%\Temp`，未修改用户环境变量。
