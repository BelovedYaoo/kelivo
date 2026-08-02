# 当前设备自撤销可信协调器

- 基线：`888c75e4`。
- 目标：仅在本地可信安全头、请求设备身份公钥、list intent、confirmed receipt、manifest lineage 和完成证明全部通过本地校验后产出可信结果。
- 边界：不实现密码算法；native 专用 ABI 未合并时通过窄接口依赖注入；任何缺失或不一致显式失败。
- 并行依赖：`feature/e2ee-self-revocation-client` 提供不可信传输 DTO；`feature/e2ee-self-revocation-native-signing` 提供专用 native 签名/验签能力，合并时再接生产适配器。
- 完成：新增 `E2eeTrustedSelfRevocationCoordinator`，验证本地安全头、请求设备公钥、intent v3 摘要、轮换与恢复成员清单链、最终签发者、completion proofFrame/proofDigest/签名。
- 信任边界：`deviceName`、`requestedAt`、`finalizedAt` 不进入可信结果；completion 仅导出签名帧覆盖的字段快照。
- 合并点：实现 `E2eeSelfRevocationIntentVerifier` 的 native 适配器；接口不接收服务端 `intentDigest`，native 必须从强类型字段重建 v3 帧并返回计算摘要。
- 验证：定向 `flutter analyze --no-pub` 通过；真实安全核心定向测试 6/6 通过。
