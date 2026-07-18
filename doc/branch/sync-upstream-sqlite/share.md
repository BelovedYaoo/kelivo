# sync/upstream-sqlite 协作记录

- 关联 Issue：BelovedYaoo/kelivo#1。
- 工作分支：`sync/upstream-sqlite`；独立工作树：`D:\Projects\Private\kelivo-sync-upstream-sqlite`。
- 定制基线：`main@2a3c7732`；上游目标：`upstream-main@16e3b21d`。
- 当前阶段：合入上游 SQLite 聊天存储、时间线与安全恢复改造。
- 必须保留：云同步 v2、写前日志、`turnId`、稳定生成终态、待确认状态区分、定制“关于”页面与本地构建配置。
- 服务地址硬切为 `https://kelivo.bemylover.top`；全仓不得残留 `https://kelivo-api.ovo-a1f.workers.dev`。
- 主工作树已有 7 个平台插件生成文件被其他进程修改，本分支不覆盖、不清理这些改动。
- 合并策略：以上游 Drift/SQLite 为存储骨架，将定制同步语义迁入数据库事务和异步查询接口，不恢复 Hive 作为聊天事实源。
