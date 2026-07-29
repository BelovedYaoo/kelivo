# 移动端恢复介质导出接线

- 基线：`feature/e2ee-chat-runtime@4838acb8`。
- Android/iOS 首设备注册现采集不同于账户密码的独立恢复口令与确认，并复用安全核心的 12 Unicode scalar / 128 UTF-8 字节校验；桌面仍仅登录。
- Provider 将一次性恢复 bootstrap preparer 注入生产认证器，并在成功、失败、冲突等所有退出路径幂等关闭；页面也在外层兜底关闭并尽早清理口令引用。
- 固定 644B 密文可用 `pretty_qr_code` 完整显示，或通过现有 `file_picker` 保存为不含账号/ID 的 `kelivo-recovery-v1.kelivo-recovery`；至少一种可用且用户明确确认后才允许注册继续，取消/文件失败均返回 false。
- 四份 ARB 与生成本地化已同步。相关定向 analyze、二维码/文件、bootstrap、Provider 所有权、移动注册校验及桌面无注册测试通过。
- 全仓 `flutter analyze` 被独立依赖目录的既有缺失开发依赖阻断：`mcp_client` 缺少 `package:test`，`workmanager_platform_interface` 缺少 `pigeon`；本次改动文件的定向 analyze 无问题。
- 合并提示：`cloud_sync_page.dart`、`cloud_sync_provider.dart` 可能与本机擦除并行任务冲突；需同时保留恢复口令/preparer 清理与本机擦除语义。
