# 设备撤销与数据换代

- 基线：`2e97a9a8`，独立 worktree `D:\Projects\Private\kelivo-device-revocation-rekey`。
- 目标：完成 Issue #51，将成员撤销、耐久 data-rekey、成员锚推进、旧 ARK 裁剪与当前设备确认擦除串成可恢复状态机。
- 测试接缝：`E2eeDataRekeyCommands`、`CloudSyncClient` v4 data-rekey 协议、`CloudSyncProvider` 撤销与冷启动恢复入口。
- 约束：固定 operation/lease/mutation 身份；requested-only 不生成新 mutation；远端确认前不推进本地成员锚或裁剪旧 ARK；不修改 Native ABI19、不部署、不访问默认安全槽。
- 协议阻断：服务端禁止轮换 issuer 自撤销，且 op3 会立即吊销目标设备会话；现有协议无法由当前设备本机完成后续 data-rekey，也缺少 requested-only 的同 mutation 受限查询。已登记 `kelivo-api#40` 并回注 App `#51`。
- 当前进度：先实现可独立完成的流式 data-rekey 执行器、其他设备撤销与固定 mutation 重放；当前设备 confirmed marker 在 `kelivo-api#40` 完成前保持失败关闭。
- 已完成：源记录/附件与暂存记录/附件可按有界分页流式累计 SHA-256；严格校验顺序、数量、阶段和最大 changeSeq，结果与既有 TypeScript 固定向量一致。
- 已完成：data-rekey 单例日志支持严格读取、租约回执耐久记录、单调续租、幂等阶段推进和 finalizing 身份校验后清理；网络延迟后的过期回执仍可落盘，但不得覆盖更新的租约事实。
- 已完成：CloudSync v4 finalize 公开返回封闭 outcome，严格解析并校验 `verification-pending` 的跨请求分页检查点；执行器可在同一 finalize mutation 的多次请求之间续租，最终仅接收完整 `finalized` 回执。
- 已完成：按账户 locator 与 operation 隔离的耐久 stage cache；pending 随机密文先原子落盘再发送，确认后先原子发布 compact canonical frame 再清除大密文，支持崩溃窗口精确恢复、数量/大小上限、进程锁、摘要校验和 finalize/abort 清理。清理只遍历白名单文件且不递归；统一句柄级防换链删除仍由 `#85` 收口。
- 已完成：pending/confirmed artifact 严格 codec；规范 JSON、canonical base64url、账户/issuer/operation/lease/mutation 全绑定。pending 可重建逐字相同 stage 请求；confirmed 仅保留生成 84 字节 staged frame 所需字段，并要求已绑定传输回执后才能产生。
- 已完成：finalize 请求耐久 artifact；签名证明、固定 mutation 与租约可在响应丢失或进程重启后逐字段原样恢复，并严格拒绝跨账户、issuer 或 operation 重放。
