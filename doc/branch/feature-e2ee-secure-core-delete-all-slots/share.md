# 协作摘要

- 基线：父提交 `26b06cd96d73ae2e601b248c635ccc663806a536` 已完成 ABI17 全槽删除；本次范围只新增安装根安全擦除 ABI，不接入上层 provider、lease 或生产调用点。
- ABI：升级至 v18，新增 capability bit 10、`kelivo_installation_root_wipe`、ffigen 绑定及 Dart `wipeInstallationRoot`；Dart 先校验 ABI/capability，再在 isolate 调用 native，绝无路径递归降级。
- Windows：仅接受严格本地绝对路径；以 no-reparse 相对句柄固定根、直属 marker 和后代项，拒绝 reparse、跨卷、硬链接及类型替换；所有固定句柄拒绝 `FILE_SHARE_DELETE`，确定性阻断 marker、根和已打开子目录的并发 rename，并在每次删除后刷新父目录。
- Android：仅在应用 UID 沙箱、安装根 `flock` 独占且内核支持 `openat2` 时发布 capability；后代解析使用 `RESOLVE_NO_XDEV | RESOLVE_NO_SYMLINKS | RESOLVE_BENEATH`，拒绝同文件系统 bind mount、跨挂载、链接和 inode 替换。旧内核失败关闭。
- 平台边界：Linux、macOS、iOS 明确不发布 capability 并返回 `UNSUPPORTED_PLATFORM`。Linux 只在测试构建复用 Android 算法，不作为生产支持平台。
- 验证：Windows native 83/83；Linux 容器隔离算法 9/9；Dart 包 28/28；包级 analyze；Windows、Android 三 ABI、Linux 双 ABI、iOS 三 ABI strict Clippy；release ABI header/绑定/导出均为 56 项且无测试符号。所有擦除测试仅使用显式隔离临时根，未访问默认生产根或槽。
- 后续边界：Dart 用户确认到 native 打开根之间尚无同一身份凭据，不能证明调用时根仍是确认时根；Issue #85 必须通过两阶段 pin/token 契约解决后，生产调用点才可接入。Android 真机内核 capability 和独占协议仍需设备级验证。
