# 协作摘要

- 分支：`feature/e2ee-ios-secure-core`，基线 `d1ae65e3`，独立工作树 `D:\Projects\Private\kelivo-ios-secure-core`。
- 完成：新增 iOS Keychain 密钥槽位后端和 `iosKeychain(4)` 能力；支持真机 arm64、模拟器 arm64/x64 Native Assets 构建目标。
- 安全：使用 `AfterFirstUnlockThisDeviceOnly`、Data Protection Keychain、显式关闭同步；不要求交互以支持后台同步，原始密钥不跨 Rust ABI，也无文件或偏好存储回退。
- 并发：Keychain 原子拒绝重复条目，沿用 `create -> duplicate -> open` 收敛；失败生成值由零化缓冲区销毁。
- 生命周期：普通登出保留加密工作区和槽位；服务端撤销不是远程擦除。本任务不扩张 ABI，主动本机密码学擦除由后续 delete-slot 生命周期实现。
- 兼容性：Runner 与 CocoaPods 最低版本从 iOS 13 硬切到 iOS 14；扩展保持既有 iOS 16.1。
- 验证：三个 iOS Rust target 的 check/Clippy 通过；native 48 项、protocol 41 项及 doctest、安全核心 Flutter 20 项、根同步 196 项通过；安全核心和根 `lib/test` 分析通过。
- 复审修复：Keychain 返回值先由 `Zeroizing<Vec<u8>>` 接管再复制到最终零化定长缓冲；Native Rust toolchain 与六个 iOS 构建工作流同步声明并安装三个 Apple target。
- 未覆盖：Windows 无 Xcode，iOS 生命周期测试仅完成目标编译，未执行模拟器 Keychain 往返或真机锁屏/重启验证。#33、#61、#63 跟踪既有门禁问题；主跟踪为 #13。
