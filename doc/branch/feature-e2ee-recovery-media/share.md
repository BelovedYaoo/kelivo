# 恢复介质安全核心协作摘要

- Primary Setpoint：安全核心 ABI v15 使用独立恢复口令加密固定 644 字节恢复介质，二维码与文件共享同一字节协议；恢复时原生一次完成介质解密、历史验证、capsule 打开和 ARK keyring 发布。
- Acceptance：protocol/native 单元测试与严格 Clippy、依赖包 Dart 分析和 Flutter 测试、根仓库云同步协议测试通过；C header、ffigen 与 Dart ABI 一致。
- Guardrails：ARK、恢复私钥和恢复介质明文不得进入 Dart；不保留无口令、旧 ABI、两阶段导入或静默降级路径；调用方口令缓冲区按消费语义清零。
- Boundary：仅修改 `dependencies/kelivo_secure_core` 的 protocol/native/C ABI/ffigen/Dart 和既有测试；不接 UI、Provider、服务端与应用层成员清单构造。
- 已完成：口令为原始合法 UTF-8，12 个 Unicode scalar 下界、128 UTF-8 字节上界；Argon2id v1.3（64 MiB、3 次、p=4）经固定 HKDF-SHA256 info 派生 XChaCha20-Poly1305 密钥，96 字节头完整作为 AAD。
- 安全复核修复：Argon2 64 MiB 工作区改由调用方显式分配并以 `Zeroizing<Vec<Block>>` 托管，HKDF 的 PRK 与单块 expand 输出也显式清零；`argon2`、`hmac`、`sha2` 启用 zeroize 特性，覆盖代码可控的堆缓冲区和密钥对象。
- 移动端工作集修复：完整成员历史保留 4096 条和单条协议上限，同时新增 16 MiB 总量双层门禁；Dart 同步构造一次有界 `TransferableTypedData`，取消额外手写展平缓冲区与发送到 worker 时的再次复制。
- 平台边界修复：生产能力仅由 Android/iOS 声明恢复介质支持；Windows 保留测试符号和普通 capsule 密封能力，但恢复身份生成、介质导出与介质恢复入口在 ABI 层失败关闭。
- 跨语言门禁：Rust 测试直接消费 Dart builder 生成的 INIT→RESUME→RESUME→REPLACE 固定 wire 与 SHA-256，逐段验证解析、双签名和状态转换。
- 已完成：导出必须同时证明本地 epoch 1 ARK、初始 capsule 与 genesis 精确绑定；导入不向 Dart 暴露恢复私钥句柄，在单个 Native 调用内失败关闭，成功原子注册当前 ARK 及必要的相邻源 epoch ARK。
- 已完成：`KELIVOMM` v1 全历史验证覆盖 op1 初始化、op2 加设备、op3 撤销轮换、op4 恢复续接和 op5 恢复替换；验证 generation/previousDigest、全历史 operationId 唯一、成员规范排序与密钥唯一、双签名和 capsule 头尾绑定。
- epoch 规则：head epoch 1 禁止 source capsule；head epoch 大于 1 必须提供最近一次 epoch 轮换前的精确 source capsule，并一次发布相邻两代 keyring；裁剪须等待未来的认证完成证明，本层不自动裁剪。
- 验证结果：protocol 57 项及 doctest、native 55 项、依赖包 Flutter 25 项、根仓库云同步协议 120 项全部通过；两 crate 严格 Clippy、依赖包 `flutter analyze` 与格式检查通过；最终增量已重新构建 Android debug APK并链接三种 Android Rust 架构；x86_64 Linux 与 aarch64 iOS Rust `cargo check` 通过。
- 验证边界：根仓库 `flutter analyze` 被既有 Issue #33 的 `mcp_client` 测试依赖缺失阻断；macOS 未覆盖，iOS 仅覆盖 Rust 条件编译与类型检查，未覆盖 Xcode 链接或真机；Android 真机上的 Argon2id 峰值工作集与 UI 可感知延迟仍需实测。
- 剩余工作：应用层 op4/op5 wire 构造由并行分支实现并已共享精确协议；恢复二维码/文件 UI、服务端恢复挑战与已认证完成证明仍由 Issue #49 跟踪。
- 自审：实现保持一个导入事务和一个 ARK keyring 真相源；KDF 在后台 isolate 执行；所有失败路径清零代码可控的持久/堆敏感缓冲区并拒绝篡改；ABI v15 为已确认的硬切，不提供数据迁移。
