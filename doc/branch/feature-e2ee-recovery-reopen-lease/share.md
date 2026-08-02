# 恢复专用重开租约

- 基线：`b3069e59`
- 复用 Issue：#49
- 目标：checkpoint 进入 `firstLocalActivated` 及后续阶段后，从精确账户、设备、epoch 绑定的 prepared/pruned 设备状态重开恢复专用能力。
- 边界：仅修改账户认证器、原生账户恢复深模块及现有相关测试，不修改 Provider/main。
- 安全约束：不回退首次初始化，不暴露 ARK 或原生密钥句柄原始值；任何状态绑定不一致均关闭租约并保留 checkpoint。
- 当前进度：已硬切 checkpoint v7，新增耐久 reopen binding；终态另持久化会话代数与 UTC 秒精度过期时间，不持久化会话 token。认证器可从精确状态摘要和账户、设备、epoch 绑定重开恢复专用 lease。
- 接口：`reopenRecovery({loginName, checkpoint})` 返回受生命周期约束的 `binding`、`proofCore` 与 `requireCurrentState`；不向调用方交出 key、ARK 或 identity 句柄。
- 资源：操作单飞，外部关闭等待活动操作；关闭失败时保留句柄和全局恢复占位，可重试收敛。
- 生产接线约束：`requireCurrentState` 必须在恢复工作区变更租约内执行；调用方还必须用已验签成员清单核对 `deviceAuthGeneration`。
- 测试：已在现有 checkpoint 测试文件补充 happy、错误阶段/账户/设备/版本/epoch/摘要、并发、关闭等待、重复关闭和恢复占位释放场景。
- 验证状态：`dart analyze lib/core/services/sync` 通过；现有 checkpoint 测试文件 5 项 secure-core 用例全部通过；`dart format` 与 `git diff --check` 通过。全仓 analyzer 仍被 path dependency 内缺失的测试/Pigeon 依赖阻断，与本分支无关。
