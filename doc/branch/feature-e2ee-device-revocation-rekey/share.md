# 设备撤销与数据换代

- 基线：`2e97a9a8`，独立 worktree `D:\Projects\Private\kelivo-device-revocation-rekey`。
- 目标：完成 Issue #51，将成员撤销、耐久 data-rekey、成员锚推进、旧 ARK 裁剪与当前设备确认擦除串成可恢复状态机。
- 测试接缝：`E2eeDataRekeyCommands`、`CloudSyncClient` v4 data-rekey 协议、`CloudSyncProvider` 撤销与冷启动恢复入口。
- 约束：固定 operation/lease/mutation 身份；requested-only 不生成新 mutation；远端确认前不推进本地成员锚或裁剪旧 ARK；不修改 Native ABI19、不部署、不访问默认安全槽。
- 协议阻断：服务端禁止轮换 issuer 自撤销，且 op3 会立即吊销目标设备会话；现有协议无法由当前设备本机完成后续 data-rekey，也缺少 requested-only 的同 mutation 受限查询。已登记 `kelivo-api#40` 并回注 App `#51`。
- 当前进度：先实现可独立完成的流式 data-rekey 执行器、其他设备撤销与固定 mutation 重放；当前设备 confirmed marker 在 `kelivo-api#40` 完成前保持失败关闭。
