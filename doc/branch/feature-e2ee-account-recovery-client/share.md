# 协作记录

## 目标

- 完成移动端账户恢复客户端闭环，桌面端不开放注册或初始化。
- 以恢复介质中的 genesis 为唯一信任锚，完整验证冻结历史后才允许 Native 解封 capsule 并签署 proof。
- 恢复私钥、ARK 和明文 nonce 不进入 Dart；所有失败关闭。

## 当前进度

- 已从 `d697d4c0` 建立独立分支与 worktree。
- 已完成授权前半程私有协调器：创建冻结 challenge、连续分页读取绑定历史、选择源代 capsule、调用 Native proof 边界、提交公开证明并接管恢复 key lease。
- challenge、数据状态、恢复 token、授权回执均采用严格强类型；冻结投影或链头不一致、过期 challenge、错误 key epoch 均失败关闭。
- 恢复口令在所有退出路径清零；Native 边界明确禁止恢复私钥、ARK 和明文 nonce 进入 Dart。
- 服务端确认 challenge 请求将移除客户端不可知的三个 expected 字段，并由服务端原子冻结 current head；客户端未固化旧 wire。
- 已在 API Issue #32 补充 challenge 启动循环依赖，并与服务端修复进程确认硬切方向。
- 设备状态存储已增加独立 8192 字节上限的账户恢复 checkpoint 密文槽，支持原样重放、旧摘要到新密文的原子替换、摘要 CAS 删除，并随设备状态 tombstone 一并清理；替换回执丢失后重放同一新密文可确认成功。
- checkpoint 使用固定二进制 v1 帧并由安装级本地槽认证密封，覆盖 `challenged -> proofReady -> authorized`；恢复 token 在磁盘上仅存在于密文载荷，编码临时字节主动清零，错误槽无法解开。
- 首次创建和阶段推进的语义重放均在重新密封前比较规范明文状态，避免随机 nonce 导致相同 checkpoint 被误判为并发冲突；并发同值赢家也可由失败方复读确认。
- authorized checkpoint 保留公开且已绑定 challenge/token 的 proof，进程重启后可与 Native 重新生成结果逐字比较并安全重放授权请求。
- 授权协调器已接入加密 checkpoint：challenge 返回后先持久化 `challenged`，Native proof 生成后先持久化 `proofReady`，服务端授权回执校验后再持久化 `authorized`。
- `proofReady` 重启会复用原 attempt/token，对 Native 重算 proof 做常数时间比较后重放授权；不一致时在发请求前失败关闭并释放 key lease。
- 服务端稳定硬切 wire 已固定在 `60d6f93b5ec296293c1f7071ba9ccf5da9d67c00`；客户端不再接旧 challenge 预期链头字段。
- 已由稳定 OpenAPI 通过生成命令引入账户恢复 API client，并完成 challenge、冻结历史与授权 transport；请求 bearer 由强类型 onboarding/recovery 联合显式选择，响应保持精确字段集校验。
- 验证：`flutter analyze lib test` 无问题；授权 4 项、真实隔离安全槽 checkpoint 1 项及工作区存储完整 116 项 Flutter 测试通过。全仓 `flutter analyze` 仍被未安装开发依赖的 `mcp_client` 测试与 Workmanager Pigeon 输入阻断，与本次改动无关。

## 协作边界

- 不部署，不触碰默认安全槽。
- 不修改原生 ABI18 擦除实现；Native 账户恢复 proof ABI 未就绪时只保留明确依赖，不加 Dart fallback。
- 测试缝：账户恢复协调器公开命令/状态流、移动端恢复入口公开交互。

## 后续依赖

- 继续接入恢复 `state/get`、resume/replacement commit，并在 `proofReady` 重启时显式协调 onboarding/recovery bearer，覆盖授权已落服务端但回执丢失的情形。
- ABI18 集成后以 ABI19 实现单次 Native 恢复 proof 事务；当前没有生产适配器，因此 UI 不得宣称恢复可用。
- 继续实现加密 checkpoint、重启/过期接管、op4/op5 与工作区耐久提交，再接 Android/iOS 二维码和恢复文件入口。
