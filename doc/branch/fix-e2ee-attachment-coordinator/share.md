# 附件协调器截止与取消修复

- 基线：`5147e661`。
- 已修复 Issue #74：远端 `cancelled`、`unauthenticated`、`forbidden` 原样越过永久失败持久化；create/chunk/commit 中断只释放租约，可从原 mutation 和 staging 断点继续。
- 已修复 Issue #56 的附件本地阶段：源文件认证、分块读取、native 加密前后、staging 流式写入/复核和 pending 密文读取均复用 `E2eeSyncExecutionBudget.checkCanContinue`。
- 文件校验、复制、增量摘要和 staging 写入以 64 KiB 为取消响应及临时内存边界；取消/截止时清零明密文，关闭文件句柄，并删除未被数据库接管的 `.next` 或 staging。
- 验证：`dart format` 完成；同步协议测试 129/129 通过；协调器、文件存储及协议测试定向 `flutter analyze` 无问题。
- 边界：未修改聊天运行时事务/扫描/原文件问题，未处理远端删除；未实际分配 4 GB 文件或测量 Android 真机文件系统取消时延，4 GB 安全性由固定分段机制覆盖。
