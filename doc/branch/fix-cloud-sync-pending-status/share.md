# fix/cloud-sync-pending-status 协作记录

- 完成：开放冲突、待发送写入、永久阻塞写入分别显示“有待确认项”“仍有数据未同步”“部分数据同步失败”。
- 完成：助手本地头像/背景导出为契约要求的显式空值，远端回放保留当前设备本地文件路径。
- 完成：旧版缺少媒体字段的 blocked mutation 使用确定性新 ID 原子式替换；其他无效 mutation 保持不变。
- 验证：同步目录 97 项、CloudSyncProvider 8 项及定向静态分析通过；完整组合测试仅有既存的 Windows `R:\Temp` 符号链接失败。
- 限制：定制仓库已关闭 GitHub Issues，无法为发现的问题执行查重、创建或关闭 Issue。
