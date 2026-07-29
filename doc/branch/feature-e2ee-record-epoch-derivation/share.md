# 协作记录

## Mini Control Contract

- Primary Setpoint：账户记录标识必须由记录自身 `keyEpoch` 对应的 ARK 精确派生；轮换后仍可打开历史记录，且不同代次不得复用记录标识。
- Acceptance：先由现有测试证明当前代次切换会破坏 epoch 1 记录，再硬切 native/C ABI/Dart 接口并通过协议、原生、依赖与根项目定向门禁。
- Guardrails：原始 ARK 不跨 FFI；缺失或已裁剪代次失败关闭；不保留无 `keyEpoch` 的旧重载或兼容路径；ABI 仅相对本分支基线递增一次。
- Boundary：`dependencies/kelivo_secure_core` 的记录 ID 派生协议、C ABI、头文件、ffigen 绑定及账户记录加密器调用点；不实现成员清单、服务端轮换或历史重加密调度。
- Risks：与成员清单分支同时修改安全核心；生成绑定与 ABI 版本冲突需在最终集成时统一；错误使用 current epoch 会造成历史记录永久不可寻址。

## 进度

- 已确认并更新 Issue #51。红灯稳定复现：当前代次切到 epoch 2 后，epoch 1 记录因 ID 被错误地按当前 ARK 重算而拒绝打开。
- 已硬切 native/C ABI/Dart `deriveAccountRecordId` 为必传 `keyEpoch`，原生在账户绑定 keyring 内精确选钥；seal 使用当前代次，open 使用记录代次；ABI 11 -> 12，绑定由 ffigen 生成。
- 已覆盖 epoch 1/2 ID 隔离、轮换后读取 epoch 1、缺失与裁剪代次失败关闭、非法 uint32 边界；未新增测试文件。
- 验证通过：native 48 项、protocol 41 项及文档测试、依赖 Flutter 19 项、根同步协议 117 项、依赖与根定向 analyze。
- 额外严格 Clippy 被既有 `record_seal_with_handle` / `record_open_with_handle` 参数数量告警阻塞，已由 Issue #62 跟踪，本分支未扩大范围处理。
- 集成注意：其他并行分支若也提升安全核心 ABI，合并时只能保留一次统一递增并同步头文件、Dart 期望值和生成绑定。
