# 协作摘要

- 已从 `kelivo-api/main@1218803` 的 OpenAPI 重新生成客户端，纯生成提交为 `11fd9d2f`；生成包 `dart analyze` 通过。
- 配对最终会话令牌由目标客户端使用 CSPRNG 生成，并在首次 consume 前写入加密恢复事务；响应丢失后的进程恢复会逐字重放同一令牌，服务端回显不同令牌时失败关闭。
- 配对恢复帧已硬切为 `KELVPT02` / v2，不读取旧帧。
- approve 的安全代次、旧清单摘要、下一版清单及其本地计算摘要已聚合为必填强类型 `CloudSyncDevicePairingMembershipCommit`。
- 账户信任模块尚未提供真实签名清单，E2EE 批准入口因此在读取 pairing secret 与生成批准 bundle 前失败关闭；后续必须在 `_requirePairingMembershipCommit` 接入真实清单，不得传占位值。
- 服务端已移除直接可信设备撤销接口，手写旧入口明确返回 `SYNC_DEVICE_ROTATION_REQUIRED`；后续必须改接签名成员清单与 ARK 轮换事务。
- 定向分析通过；协议测试 118/118、Provider/设置测试 62/62 通过。首次测试曾因 `R:\Temp` 空间不足失败，改用 `%LOCALAPPDATA%\Temp` 后原生构建与测试通过。

## 最终服务端契约接入

- 基线：服务端 `kelivo-api/main@01cf690`，客户端主开发分支 `feature/e2ee-chat-runtime@b8c1b7bd`。
- 目标：硬切会话元数据 v4，分别持久化 `sessionGeneration` 与 `authGeneration`；严格验证配对签发者双公钥、版本、认证世代、完整安全状态与回执。
- 激活门禁：移动端注册和配对必须先验证并安装 schema21 成员锚点，成功后才能激活会话并清理恢复状态。
- 场景：覆盖正常注册/查询/审批/消费，缺失或额外字段、非法 uint32、错误签名/摘要/世代/回执，以及响应丢失重放与锚点失败时禁止激活。
- 当前：准备合入 `b8c1b7bd`，随后仅通过生成脚本更新 OpenAPI 客户端。
- 已合入客户端基线并按服务端 `01cf690` 重新生成客户端；附件契约已适配 chunk/manifest 双代次与 manifest revision。
- 会话元数据已硬切 v4，`authGeneration` 与 `sessionGeneration` 独立持久化；仅保存公开完整安全状态、公开成员材料和明确 bootstrap 来源，不保存 ARK、恢复私钥或恢复口令。
- 注册 finish、配对 query/consume 已改为基于原始 JSON 的精确键校验，禁止依赖生成模型忽略未知字段。
- 首设备注册结果会以本地 ARK 重新验证签名 genesis、成员双公钥、认证代次和账户密钥信封，验证成功后才生成待安装 bootstrap；三个相关文件定向 `flutter analyze` 已通过。
- 恢复二维码/文件的独立恢复口令由恢复介质分支负责；本分支明确不向 session/bootstrap 增加任何恢复口令字段。
- 目标设备配对恢复事务已硬切 `KELVPT03`，加密保存签发者 key version、auth generation、双公钥和冻结账户信封；首次 consume 与响应丢失后的跨重启重放使用同一材料校验。
- 配对 consume 结果必须由本地 ARK 验证签名成员清单、完整安全状态、消费回执、目标成员和签发者公开身份，成功后才生成 pairing bootstrap；相关文件定向 `flutter analyze` 已通过。
- 内容运行时已建立成员锚点激活门禁：无 bootstrap 时必须用 ARK 读出并校验本地锚点；有 bootstrap 时必须重验签名清单、幂等安装锚点、确认恢复事务并把会话重写为 v4，完成前不得初始化聊天内容或构造网络传输层。
- 前台 Provider 与 headless 后台运行时共用同一提交顺序；确认或会话重写失败会保留 bootstrap，重启后可幂等重放，冲突锚点失败关闭。
- 注册恢复测试夹具已硬切 `KELVRT02`，使用真实 ARK 签名 genesis；附件测试已分别断言 `chunkKeyEpoch`、`manifestKeyEpoch`、`manifestRevision`，不再沿用旧 `keyEpoch` HTTP 字段。
- 验证：`flutter analyze lib test` 通过；协议 122/122、Provider/内容运行时 79/79、工作区 101/101 通过。全仓 `flutter analyze` 被未改动的 `dependencies/mcp_client` 缺少 `package:test` 阻断；全量 `flutter test` 在 10 分钟执行上限内未退出，不能计为通过。
