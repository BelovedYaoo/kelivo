# 协作摘要

- 跟踪：Issue #51、#66。
- 基线：`feature/e2ee-chat-runtime@d91bbb38`；独立 worktree `D:\Projects\Private\_worktrees\kelivo-rekey-production-wiring`。
- Primary Setpoint：将现有 data-rekey 执行器、数据库日志/暂存、生产密码会话与当前设备自撤销状态机组合为可注入 Provider 的失败关闭生产实现。
- Acceptance：远端撤销确认后可完成记录/附件换钥、成员锚提交、旧 ARK 裁剪与最终本机擦除；中断后按同一 operation/mutation 恢复；定向分析与相关回归通过。
- Guardrails：不修改同步客户端、账户恢复模型/检查点/认证器；远端 ready 前不推进成员锚或裁剪旧钥；本地换钥确认前不得报告撤销完成或启动擦除。
- Boundary：`lib/core/providers/**`、`lib/core/services/sync/**` 中新的窄生产组合层、`lib/main.dart` 及既有相关测试；仅在确有必要时触及现有 Provider。
- Risks：自撤销 typed adapter 尚由并行分支实现；数据库/密钥租约释放顺序若错误会造成不可恢复擦除；requested-only 冷启动若缺查询合同必须失败关闭。

## 最小场景

- Happy：从已认证当前设备发起撤销，复用固定 mutation，服务端提交后完整换钥、提交本地状态、确认清理，再执行安装级擦除。
- Boundary：账户没有待换钥记录或附件；ready 状态重复进入；进程重启后从既有 journal/stage 继续；同一 operation 重复调用幂等收敛。
- Failure：远端撤销结果未知、租约/阶段/证明不匹配、数据库暂存失败、成员状态 CAS 冲突、旧 ARK 裁剪失败或擦除失败时均保留可恢复状态并禁止成功回执。
- State transition：requested -> remote-confirmed -> rekey-ready -> local-committed -> remote-acknowledged -> wipe-confirmed；禁止跳级或倒退。

## 完成摘要

- 新增可信设备侧生产 runner，组合真实设备状态、安全核心目标密码会话、数据库 journal/stage、远端 data-rekey 与本地成员锚/旧 ARK 裁剪，并串行化同实例执行。
- 目标设备状态被独立打开为记录、附件清单和附件分块三个 ARK 句柄；严格校验源/目标 user、device、keyVersion、keyEpoch 与身份公钥，安全句柄清理允许一次有界重试。
- 附件密码会话拒绝重复接管同一个 ARK 句柄，避免清单与分块关闭时重复释放。
- 现有数据库编排测试改为执行真实生产 runner，覆盖 source -> ready -> pruned、pruned 状态重复恢复与重复句柄边界；确认旧 epoch 已不可派生。
- 已通过定向 `flutter analyze --no-pub`；通过安全核心包装入口运行完整“E2EE 账户密钥变更编排”测试组，共 9 项。
- 未推送、未部署、未访问默认安全槽。

## 集成阻塞

- 自撤销请求仍需把 `selfRevocationMutationId` 与 `selfRevocationIntentDigest` 透传并绑定到设备换钥 op3；当前 typed 客户端提交模型尚无这两个字段。
- 请求设备生成自撤销 intent 仍缺设备身份专用签名 ABI；不得借用登录、data-rekey 或账户信任证明域。
- 因服务端协议要求另一台可信设备处理自撤销换钥，本 runner 只作为该可信设备处理器的生产执行核心；不得直接注入为请求设备同机换钥流程。
- 真实记录重包与附件清单重包已有独立组件测试；当前 production runner 集成用例使用空远端源，后续仍需补一条非空记录/附件的全链路夹具。
