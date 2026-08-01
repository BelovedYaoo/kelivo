# 移动端账户恢复入口

## 目标

- 仅 Android/iOS 提供账户恢复入口。
- 仅接受固定 644 字节二维码或恢复文件，并要求独立恢复口令。
- 页面只编排公开协议材料与不透明句柄，私钥、ARK、nonce 明文始终留在 Native。
- 恢复流程可在失败、退出或进程重启后显式继续或清理，不提供假成功与降级路径。

## 当前状态

- 基线：`feature/e2ee-chat-runtime@07660680`。
- 工作分支：`feature/e2ee-mobile-account-recovery-ui`。
- 已完成移动恢复 Provider 深模块 seam：`E2eeAccountRecoveryCommand` 接管并清零调用方字节，`CloudSyncProvider.startAccountRecovery` 只在 Android/iOS 且真实 runner 已注入时开放。
- Provider 统一发布认证、介质验证、可信设备重建、加密数据恢复、完成/失败进度；runner 不得直接发布终态或回退进度。
- 成功、协议失败、Windows 强制拒绝三条测试通过；成功或失败后 runner 所见密码、恢复口令与 644 字节介质均已清零。
- 正在实现移动端二维码/恢复文件选择、口令输入与可恢复进度页面。

## 并行接口依赖

- ABI19：生产 adapter 为 `E2eeNativeAccountRecoveryProofCore`，现有 `E2eeAccountRecoveryProofCore.verifyHistoryAndCreateProof` 保持不变；返回 lease 的 `close()` 必须幂等。
- 数据换钥：#51 将提供“已提交 membership checkpoint + recovery actor/keyring -> 幂等完成本轮 data-rekey”的执行入口；最终完整会话由恢复完成 checkpoint/finalize 返回。
- 两者合入前 production runner 保持未注入，移动入口不得提交，不提供假成功或降级。

## 验证 seam

- 移动端页面：入口可见性、二维码/文件选择、口令校验、加载/失败/继续/完成状态及生命周期清理。
- `CloudSyncProvider` 公开恢复命令：合法流程、边界输入、协议失败与可恢复状态转换。
- 不直接测试 Native 私有实现，不访问默认安全槽。
