# fix/cloud-sync-v2 协作记录

- 目标：将云同步协议升级到 v2，修复契约拒绝、重复重投、冲突丢数据和 Android UI 卡顿。
- 分支：`fix/cloud-sync-v2`，基于 `main@783bb62a`；完成后合并回 `main` 并清理 worktree。
- 测试 seam：同步 journal/outbox 模块、批量 Adapter 接口、生成客户端传输闭环。
- 当前阶段：建立红灯测试与 v2 契约，尚未执行生产数据重建。
- 协作约束：不要修改平台生成文件；同步协议、Hive 状态和 Provider 写入口变更需先在此记录。

