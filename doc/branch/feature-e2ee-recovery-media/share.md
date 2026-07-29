# 恢复介质安全核心协作摘要

- Primary Setpoint：安全核心 ABI v15 使用独立恢复口令加密固定 644 字节恢复介质，二维码与文件共享同一字节协议；恢复时原生一次完成介质解密、历史验证、capsule 打开和 ARK keyring 发布。
- Acceptance：protocol/native 单元测试与严格 Clippy、依赖包 Dart 分析和 Flutter 测试、根仓库云同步协议测试通过；C header、ffigen 与 Dart ABI 一致。
- Guardrails：ARK、恢复私钥和恢复介质明文不得进入 Dart；不保留无口令、旧 ABI、两阶段导入或静默降级路径；调用方口令缓冲区按消费语义清零。
- Boundary：仅修改 `dependencies/kelivo_secure_core` 的 protocol/native/C ABI/ffigen/Dart 和既有测试；不接 UI、Provider、服务端与应用层成员清单构造。
- 已完成：口令为原始合法 UTF-8，12 个 Unicode scalar 下界、128 UTF-8 字节上界；Argon2id v1.3（64 MiB、3 次、p=4）经固定 HKDF-SHA256 info 派生 XChaCha20-Poly1305 密钥，96 字节头完整作为 AAD。
- 已完成：导出必须同时证明本地 epoch 1 ARK、初始 capsule 与 genesis 精确绑定；导入不向 Dart 暴露恢复私钥句柄，在单个 Native 调用内失败关闭，成功原子注册当前 ARK 及必要的相邻源 epoch ARK。
- 已完成：`KELIVOMM` v1 全历史验证覆盖 op1 初始化、op2 加设备、op3 撤销轮换、op4 恢复续接和 op5 恢复替换；验证 generation/previousDigest、全历史 operationId 唯一、成员规范排序与密钥唯一、双签名和 capsule 头尾绑定。
- epoch 规则：head epoch 1 禁止 source capsule；head epoch 大于 1 必须提供最近一次 epoch 轮换前的精确 source capsule，并一次发布相邻两代 keyring；裁剪须等待未来的认证完成证明，本层不自动裁剪。
- 验证结果：protocol 55 项、native 55 项、依赖包 Flutter 24 项、根仓库云同步协议 120 项全部通过；两 crate 严格 Clippy、依赖包 `dart analyze` 与格式检查通过。
- 验证边界：根仓库 `flutter analyze` 被既有 Issue #33 的 `mcp_client` 测试依赖缺失阻断；Android/iOS/macOS/Linux 目标编译未在本工作树执行，Argon2id 移动端峰值和平台原生链接仍需目标构建验证。
- 剩余工作：应用层 op4/op5 wire 构造由并行分支实现并已共享精确协议；恢复二维码/文件 UI、服务端恢复挑战与已认证完成证明仍由 Issue #49 跟踪。
- 自审：实现保持一个导入事务和一个 ARK keyring 真相源；KDF 在后台 isolate 执行且无额外明文复制；所有失败路径清零敏感缓冲区并拒绝篡改；ABI v15 为已确认的硬切，不提供数据迁移。
