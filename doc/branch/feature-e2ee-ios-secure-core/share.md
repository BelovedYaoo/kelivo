# 协作摘要

- 完成：`feature/e2ee-ios-secure-core` 已非快进合入 `feature/e2ee-chat-runtime`，独立工作树待清理。
- 完成：新增 iOS Keychain 密钥槽位后端和 `iosKeychain(4)` 能力；支持真机 arm64、模拟器 arm64/x64 Native Assets 构建目标。
- 安全：使用 `AfterFirstUnlockThisDeviceOnly`、Data Protection Keychain、显式关闭同步；不要求交互以支持后台同步，原始密钥不跨 Rust ABI，也无文件或偏好存储回退。
- 并发：Keychain 原子拒绝重复条目，沿用 `create -> duplicate -> open` 收敛；失败生成值由零化缓冲区销毁。
- 生命周期：普通登出保留加密工作区和槽位；服务端撤销不是远程擦除。本任务不扩张 ABI，主动本机密码学擦除由后续 delete-slot 生命周期实现。
- 兼容性：Runner 与 CocoaPods 最低版本从 iOS 13 硬切到 iOS 14；扩展保持既有 iOS 16.1。
- 验证：ABI 13 下三个 iOS Rust target 的 check/严格 Clippy 通过；native 49 项、protocol 41 项及 5 个 doctest、安全核心 Flutter 21 项、根同步协议 120 项通过；安全核心与根定向分析通过。
- 复审修复：Keychain 返回值先由 `Zeroizing<Vec<u8>>` 接管再复制到最终零化定长缓冲；Native Rust toolchain 与六个 iOS 构建工作流同步声明并安装三个 Apple target。
- 未覆盖：Windows 无 Xcode，尚未执行最终 Xcode 链接、模拟器 Keychain 往返、iOS 14 真机安装或锁屏/重启后的后台读取。#33、#63 跟踪既有门禁问题；主跟踪为 #13。
