# 协作摘要

- 跟踪：Issue #50、#51；基线 `feature/e2ee-chat-runtime@e1e97478`。
- Primary Setpoint：让当前设备自撤销与手动撤销其他设备在生产运行时只能经已验证成员清单、op3、data-rekey 与可信终态收敛，随后才允许本地密码学擦除。
- Acceptance：请求设备只签固定 intent 并持久/有界轮询；另一可信设备验签并执行 op3 + data-rekey；最后设备进入恢复 replacement；前后台入口使用同一资源租约、取消与截止规则；能力不完整时 UI 禁用。
- Guardrails：请求设备不得接触新 ARK；不得把未验证服务端状态升级为 trusted；不得保留直接撤会话而不换 ARK 的路径；不得自造 native 签名/验签；不得使用旧 workers.dev 域名。
- Boundary：`lib/main.dart`、`lib/core/providers/cloud_sync_provider.dart`、`lib/core/services/sync/**` 的窄生产组合模块及既有相关测试。
- Risks：native intent signer/verifier 分支尚未合并；production rekey runner 可能需移植；恢复 replacement 的生产恢复入口可能尚未形成可调用接口。

## 最小场景

- Happy：请求设备固定 intent -> continuation 轮询 -> 另一可信设备验签 -> op3/data-rekey -> trusted confirmed -> 本地 wipe。
- Response loss：create/commit/complete 响应丢失后复用相同 mutation/operation，重启后继续收敛。
- Pending：没有在线处理设备时保持 pending，不擦除、不伪成功；后台与前台轮询均受截止和取消约束。
- Recovery：最后设备或没有其他可信设备时显式进入既有 recovery replacement，不生成普通撤销成功回执。
- Failure：401、continuation 过期、服务端分叉、manifest/proof/completion 验证失败均失败关闭。
- Manual revoke：撤销其他设备同样走已验证 op3 + data-rekey，禁止仅撤会话。

## 当前进度

- 正在核对现有运行时入口、typed adapter、可信状态验证与并行分支依赖；未推送、未部署。
