# 协作状态

- 基线：`feature/e2ee-chat-runtime@2e97a9a8eefdea51193d7b9c47bf739ed4e3e384`。
- 目标：为 App #49 实现 ABI19 恢复挑战证明与 replacement/resume 准备事务，秘密仅存在于 Native。
- 当前：协议层、Native execution、ABI 19 C header、ffigen、Dart 不透明 execution 包装与应用 ProofCore 适配均已完成。协议严格解析并绑定 316 字节 challenge、100 字节 HPKE sealed nonce、108 字节 proof transcript，并能准备 resume/replacement 提交；Native 原子执行拥有恢复 ARK，缓存相同 prepare 输入，任何上下文或认证代数错配都会销毁 execution 与 ARK。独立恢复口令在应用、Dart worker 与 Native 临时缓冲区均按所有退出路径清零。
- 已验证：protocol 完整测试（66 个单测、1 个 doctest、4 个 compile-fail）通过；Native 全量测试在显式本地临时目录下连续两次 84/84 通过；protocol/native host 严格 Clippy 通过；Android 3 个、Linux 2 个、iOS 3 个已安装目标均以 `--all-targets --all-features -- -D warnings` 通过。
- Flutter 验证：`kelivo_secure_core` analyze 通过且 gated 测试 31/31 通过；根应用 `flutter analyze lib test` 通过；Native 账户恢复适配与授权器定向测试 13/13 通过。release DLL 的 59 个导出与 C header 59 个声明完全一致，且不含 `kelivo_test_*` 导出。
- 环境结论：默认 `R:\Temp` 会使既有 Windows installation-root wipe 临时根 `canonicalize` 返回 OS error 1，并在 `panic=abort` 下表现为 `STATUS_STACK_BUFFER_OVERRUN`；改用普通本地临时目录后基线与本分支均通过，结论已记录到 App Issue #37。
- 审查修复：ABI19 接入审查发现上层在 `ready` 时固定省略 source capsule，导致任何已完成过 ARK 轮换的账户无法再次恢复。现已按公开授权器 seam 完成红绿闭环：`keyEpoch > 1` 只从完整历史中唯一的相邻代次跃迁选择最近轮换前驱，缺失、多义或恢复公钥/capsule 版本绑定错误均在进入 Native 前失败；签名清单中的 capsule 摘要仍由 Native 最终验证。授权器 15/15 测试及相关 analyze 已通过。
- 安全复审：修复 `RecoverResume` 后 replacement 仅检查任意既有目标、未绑定刚恢复主体的协议缺口。协议现要求链头 issuer/subject 均等于 challenge 设备，并覆盖跨主体拒绝与同主体成功；protocol 68 个单测、1 个 doctest、4 个 compile-fail 及严格 Clippy 通过。
- 敏感材料复审：`AccountRecoveryProofMaterial` 现实现显式 `Zeroize` 与析构清零，并直接在最终 material 内构造包含 nonce 的 transcript，避免遗留未受保护的局部副本；固定向量、显式归零契约、protocol 完整测试与严格 Clippy 均通过。
- 待完成：完成 Native/FFI 失败路径与 challenge 绑定的最终复审；上层恢复 runner 仍待组装。完整根测试受既有 App #53 挂起边界影响，因此本次使用需求相关定向测试闭环。
- 边界：不访问默认安全槽、不部署；Windows/Linux/macOS 恢复执行能力保持 Unsupported。
