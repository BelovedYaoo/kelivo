# 协作摘要

- 目标：硬切实现结构化 `ChatMessage` 附件的领域模型与本地 SQLCipher 仓储闭环。
- 跟踪：https://github.com/BelovedYaoo/kelivo/issues/50 与 https://github.com/BelovedYaoo/kelivo/issues/52
- 已完成：`ChatMessage` 暴露最多 32 个不可变有序 `ChatMessageAttachment`，包含完整本地资产、展示元数据及全空或完整的远端三元组；JSON 硬切要求显式 `attachments`。
- 已完成：完整消息读取统一批量联表 `message_asset_rows JOIN asset_rows` 并校验 ordinal 连续；写入在现有消息事务内原子落消息、资产和引用，外层 E2EE intent 失败会整体回滚。
- 已完成：本地文本更新不会用缓存里的空远端身份覆盖数据库已回填身份，也不会删除未变化引用并级联破坏上传状态。
- 已完成：仓储新写路径不从 `[image:]` / `[file:]` marker 推断附件；同步适配器和 UI 未修改。
- 验证：定向 analyze 通过；模型 11 项、仓储 14 项、附件 GC/快照/备份/同步协议扩展 178 项通过，Windows 符号链接权限场景跳过 1 项。
- 剩余接线：`ChatService` 与 UI 仍有旧 marker 生成、启动回填和 GC 兼容保护，需在上层硬切结构化附件时一并删除；本分支不引入新的 marker 兼容。
