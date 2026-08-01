# 协作状态

- 基线：`feature/e2ee-chat-runtime@2e97a9a8eefdea51193d7b9c47bf739ed4e3e384`。
- 完成：ABI19 challenge/proof、Native 原子恢复 execution、resume/replacement 准备事务、Dart 不透明包装及应用 ProofCore 适配。恢复 ARK 与口令秘密仅存在于 Native/受控临时缓冲区并在失败路径清零。
- 审查修复：轮换账户恢复时唯一选择相邻前驱 capsule；恢复接续后的 replacement 严格绑定同一恢复主体；proof material 显式 `Zeroize` 并避免 nonce transcript 局部副本。
- v2 硬切：成员清单使用 format 2/header 260，`operationAuthorizationDigest[224..256]` 由签名覆盖，成员计数位于 `[256..260]`；仅 revoke-rotate 允许非零摘要。恢复介质使用 `KELVRM02`/version 2、genesis 476、plaintext 564、media 676，wrap-key HKDF info 使用 `.v2` 域；旧 media 与旧 manifest 均失败关闭。
- 互操作依据：设备分支 `e6972d8a` 冻结 init -> addDevice -> revokeRotate -> recoverResume -> recoverReplace 五段 Dart v2 向量。Rust 已验证五个摘要、完整历史、全部当前签名、op3/op5 过渡签名、G1..5/E1,1,2,2,3、op3 非零授权摘要及其余操作全零摘要。
- 验证：protocol 69 个单测、1 个 doctest、4 个 compile-fail 与严格 Clippy；Native 默认特性 84/84 与严格 Clippy；`kelivo_secure_core` analyze、显式安全测试 31/31；根授权器 15/15 与定向 analyze；Dart 五段固定向量 1/1、相关合并回归 132/132。根无范围 analyze 受既有 Issue #80 阻断。
- 边界：不访问默认安全槽、不部署；Windows/Linux/macOS 恢复执行能力保持 Unsupported。Native 恢复执行内部可持有 E/E+1 双代 ARK，但 Dart 公共层不拥有该句柄；上层目前只能封装恢复前的 identity-only 状态，双代状态落盘与完成重加密后的裁剪落盘需要 Issue #92 的专用原子 ABI，禁止直接暴露内部 ARK 句柄。
