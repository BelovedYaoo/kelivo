# 协作状态

- 完成 ABI19 账户恢复 challenge/proof、Native 恢复 execution、resume/replacement 准备事务及双代设备状态原子落盘与裁剪激活；公共层不导出 raw ARK。
- 恢复介质与成员清单已硬切 v2；完整历史、capsule、完成证明、设备身份、操作授权摘要和持久化状态绑定均由 Native 失败关闭验证。
- 经一次或多次 resume 的恢复必须使用独立 376 字节 `KELIVR2C` 替换挑战；初始即 Ready 且目标设备尚未入成员时才允许旧 316 字节挑战直达 replacement。
- 第二阶段使用独立 HPKE、proof 与 trust-signature 域，Native 重算并返回已验证的 request digest；replacement-only execution 不能被 resume 提交或状态候选消费。
- 原子状态入口可生成 E/E+1 双代密文与仅 E+1 候选，并仅在完成证明和精确状态绑定验证后激活裁剪状态。
- 验证：protocol 72/72、1 个 doctest、4 个 compile-fail 与严格 Clippy；Native 89/89 与严格 Clippy；`kelivo_secure_core` analyze、Dart 安全测试 33/33；根 `flutter analyze lib` 通过。
- 已登记并解决 Issue #92、#94。根全量 analyze 的既有 path dependency 问题仍由 Issue #80 跟踪；Windows Dart 层按能力门禁保持 Unsupported，Android/iOS 实机组合由后续集成分支完成。
