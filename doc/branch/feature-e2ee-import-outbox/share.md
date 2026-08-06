# feature/e2ee-import-outbox

## 当前任务

- 基线：`feature/e2ee-chat-runtime@888c75e4`
- Issue：#50
- 目标：聊天导入与恢复在 SQLCipher 实体写入事务内生成 E2EE dirty intent；远端 apply 与账户恢复内部切换不得形成回声。
- 验收：全量导入、合并、失败回滚、附件引用/删除、远端 apply 无回声；批量有界且不上传 DB、ZIP 或明文。

## 当前进度

- 已建立独立 worktree 与分支。
- 正在梳理 `ChatService.runImportBatch`、NDJSON/快照入口和仓储事务边界。
