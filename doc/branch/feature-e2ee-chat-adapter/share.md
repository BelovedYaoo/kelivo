# 协作摘要

- 目标：实现六类聊天实体的严格 E2EE 快照读取与远端 apply 适配器。
- 基线：从 `feature/e2ee-chat-runtime` 的 `eb81885f` 建立独立 worktree。
- 完成：新增六类聊天实体的严格快照读取与事务内远端 apply，value 按依赖正序、tombstone 反序，同层按 changeSeq 稳定排序。
- 完成：pull 全程占用 ChatService 远端队列；checkpoint 提交后只刷新一次，失败不刷新，close 等待 pull 收口。
- 完成：turn 墓碑仅凭 turnId 查询归属并幂等删除；远端 selection/删除不再改写会话权威时间。
- 完成：附件模型尚不可逆时明确失败并回滚，禁止上传本地路径或伪造空附件成功。
- 验证：数据库约束测试 55 项、ChatService 测试 40 项通过；任务文件静态分析通过。
- 已知基线：根 `flutter analyze` 仍被 `dependencies/mcp_client` 缺少 `package:test` 的既有问题阻断（Issue #33）。
- 约束：不改数据库 schema/R2，不触碰生产组装、账户 ARK loader，不保留旧 payload 或兼容路径。
- 跟踪：https://github.com/BelovedYaoo/kelivo/issues/50
