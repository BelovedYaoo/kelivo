# 禁用未加密远端备份协作记录

- 目标：处理 Issue #67，公开前硬切禁用 WebDAV/S3 普通 ZIP 远端备份与自动调度。
- 基线：`feature/e2ee-chat-runtime` 的 `76e82521`。
- 完成：删除远端模型、客户端、Provider、提醒调度及移动端/桌面端入口；备份页只保留用户主动选择目标的本地导入导出。
- 清理：应用启动在工作区初始化前删除旧 WebDAV/S3 凭据、提醒状态和旧 `kelivo_backup_*` 明文临时产物；失败时阻止应用进入业务界面。
- 隔离：本地导出使用独立 `kelivo_local_export_*` 命名与 API，不含网络依赖；旧远端键同时被设置导入导出过滤器排除。
- 验证：相关测试 53 项通过，1 项因 Windows 无符号链接权限跳过；14 个改动文件定向 `flutter analyze` 无问题；`flutter gen-l10n` 已执行且 `desiredFileName.txt` 为 `{}`。
- 已知基线：全仓 `flutter analyze` 因 `dependencies/mcp_client` 缺少 `package:test`、`workmanager_platform_interface` 缺少 Pigeon 依赖而产生 755 项既有错误。
- 范围外：不实现 Issue #68 的备份 AEAD，不改聊天云同步。
