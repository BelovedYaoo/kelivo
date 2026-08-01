# 移动端账户恢复入口

- Android/iOS 登录页已增加账户恢复入口；桌面端不展示。真实 runner 未注入时入口保持禁用，不提供假成功或降级。
- 恢复页支持扫描二维码或流式读取 `.kelivo-recovery` 文件，只接受固定 644 字节密文；调用方缓冲、页面持有介质和提交命令材料均按生命周期清零。
- 页面校验账户、账户密码、独立恢复口令和设备名称，并统一展示认证、介质验证、可信设备重建、加密数据恢复与完成/失败进度。
- 损坏的新介质会清除旧介质和提交资格，避免错误提示后误提交旧数据；选择按钮采用纵向布局以覆盖窄屏。
- Provider 提交边界已由 `E2eeAccountRecoveryCommand` 和 `CloudSyncProvider.startAccountRecovery` 承担；后续 ABI19 与数据换钥 runner 合入后仅需注入生产 factory。
- `flutter gen-l10n` 已运行，四份 ARB 同步且 `desiredFileName.txt` 为 `{}`。
- 17 项恢复相关测试、变更文件静态分析、`flutter analyze lib test` 均通过。根 `flutter analyze` 仍受既有 Issue #80 阻断；完整测试在数据库约束第 231 项后命中既有 #53 挂起，确认无日志与 CPU 进展后停止。
