# 协作摘要

- 目标：为 v3 云同步记录提供基于不透明账户根密钥 ARK 句柄的跨设备密封与开启能力，关联 Issue #47。
- 边界：仅修改 `dependencies/kelivo_secure_core` 的 Rust、C ABI、Dart 封装及现有测试；本分支不接生产同步协调器。
- 约束：复用现有记录信封格式；Dart 不读取原始 ARK；错误 epoch、record ID、AAD、密文或句柄必须失败关闭。
- 已将原生 ABI 升至 v6，新增 `kelivo_account_record_seal/open`；本机槽与 ARK 复用同一记录信封实现，但句柄类型严格隔离。
- Dart 新增 `sealAccountRecord/openAccountRecord`，ARK 在异步操作期间保持占用，原始账户密钥始终留在 Rust 句柄表。
- 验证：Rust 40/40、Dart 安全核心 12/12、安全核心与根 `lib + test` 分析通过；根组合回归 180/181，通过的 180 项含协议与 Provider 全集。
- 唯一组合失败是既有真实 isolate 文件锁时序用例，单独复验通过，已记录 Issue #48；本分支没有修改该路径。
- 自审：错误 ARK、epoch、record ID、AAD、篡改信封、关闭句柄与句柄类型混淆均失败关闭，认证失败输出长度归零且明文缓冲区未写入。
