# E2EE 成员清单协作摘要

- 分支：`feature/e2ee-membership-manifest`，基线 `d1ae65e3`。
- `E2eeAccountTrustManifestModule` 集中创建、解析、ARK 锚验证、分页 history 链验证、服务端投影核对和恢复 ARK 绑定，只输出不可外部构造的 `E2eeVerifiedMembership`。
- v1 wire 固定为 `356 + 88*N`：header 228、成员 88、旧 epoch 过渡签名 64、当前 epoch 签名 64；`1 <= N <= 256`，总长 `444..22884`。完整 manifest digest 是 `SHA256(payload || transition || current)`。
- payload 显式签入当前账户信任公钥、上一份完整清单摘要、恢复公钥与版本、恢复 capsule 版本与摘要、操作和规范排序成员。初始化/新增设备的 transition 必须全零；撤销轮换由旧 epoch 和新 epoch 对同一 payload 分别签名。
- 客户端公开 API 不接受可由服务端字节构造的恢复信任锚；恢复导入必须等待安全内核提供原生能力后再接入。history 只能从已经验证的成员状态开始，按 generation 无跳跃验证；单批最多 256 份，可分页继续。
- 恢复 X25519 公钥必须与所有设备 X25519 公钥不同；本地创建和不可信二进制解析共用同一条硬校验。单一恶意服务器仍可回放有效旧前缀造成回滚或拒绝服务，但不能伪造 ARK 或新 epoch 链。
- 撤销禁止 issuer 自撤销；issuer 在新旧清单均存在且不变。配对成员写入激活后的 `authGeneration=pre+1`，设备 keyVersion/authGeneration 限制在服务端 31 位整数域。
- current projection 的 `lastOperationId` 必填且与清单 operationId 一致；`dataRekeyPhase` 是必填强类型运行状态。初始化/新增/配对要求 `ready`，轮换提交要求 `rekeyPending`；普通 current 返回服务端报告相位，但不能据此裁剪旧 ARK。
- 安全内核 ABI v12 增加严格 Ed25519/X25519 公钥验证；ARK 派生可信公钥与 history 候选公钥使用不同 Dart 类型，后者只证明严格数学验签，不自行建立信任。
- 已通过：根模块和协议测试定向 analyze；3 个成员清单需求测试；`kelivo_secure_core` Dart 20/20；native Rust 49/49；protocol Rust 41/41、doctest 5/5；ffigen 重新生成。
- 严格 clippy 仍被既存非本分支告警阻断：native 两个 FFI 函数参数过多、protocol `AccountRootKeyring.len` 缺少 `is_empty`。已记录 Issue #62，未扩展本任务修复。
- 后续接线：registration finish 直接使用创世输出和本地 raw recovery capsule；配对 consume 三字段全部核对；服务端提供不可变 history；rekey completion proof 独立实现。
