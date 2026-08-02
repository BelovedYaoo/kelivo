# 自撤销 operation 3 绑定

- 对应 Issue：#51；基线提交：`888c75e40526d967566fb7c99fe079ff040292fd`。
- 已完成：新增不可变自撤销授权绑定；设备轮换请求、响应、账户换钥 binding/receipt 与 operation 3 成员清单逐层绑定 mutation、intent digest、operation、安全代次和前序清单摘要。
- 已完成：新增 `CloudSyncDeviceRotationTransport -> E2eeAccountKeyTransitionRemoteCommit` 窄适配器；仅接受已验证 `E2eeDeviceStateKeyTransitionPlan`，提交后验证服务端回执，并通过 ready 状态和完成证明确认远端收敛。
- 模式边界：direct 与 self-revocation 使用独立命名构造器；direct 响应携带自撤销字段、自撤销响应缺失或替换任一字段都会拒绝。
- 组合点：`2bd88852` 的可信协调器产出 `E2eeVerifiedSelfRevocationIntent` 后，将其字段构造成 `E2eeSelfRevocationRotationBinding`；同一 binding 同时进入 operation 3 清单、账户换钥 binding、轮换请求和 remote commit 适配器。
- 验证：Dart 全量静态分析无问题；协议测试 186 项、账户换钥状态机 11 项、provider 内容门禁 130 项通过；新增定向用例覆盖正常路径、边界字段、mutation/intent 替换、direct/self 串模和错误 ready 状态。
- 兼容边界：轮换请求/结果的旧未命名构造器已硬切为 `.direct` 与 `.selfRevocation`，符合本轮无需兼容旧调用方的约束。
