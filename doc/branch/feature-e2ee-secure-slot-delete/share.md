# 协作摘要

- 跟踪：https://github.com/BelovedYaoo/kelivo/issues/64；#63 是无关的 actionlint 基线问题。
- 完成：安全核心硬切 ABI v14，新增 `kelivo_key_slot_delete`、`slotInUse(39)`、Dart `deleteSlot` 与 ffigen 绑定，并补齐 header 遗漏的 iOS Keychain 后端编号 4。
- 安全语义：槽位缺失幂等成功；同进程打开或仍有在途密钥借用时拒绝；系统存储、权限、认证和 IO 错误失败关闭，不做文件或偏好回退。
- 平台：Windows 删除 DPAPI 包装密文；Android 在持久锁和目录 fsync 下只删目标槽密文，保留所有槽共享的 Keystore 主包装密钥；iOS 删除 Data Protection Keychain 条目。macOS/Linux 继续明确 unsupported。
- 边界：普通登出保持槽位，上层本机安全重置流程尚未调用新 API。
- 验证：Rust 52 项、严格主机 Clippy、三个 iOS 与三个 Android 目标严格 Clippy、依赖 Flutter 22 项和 analyze、根数据库/协议 214 项和定向 analyze 均通过；Windows Release DLL 的 47 个导出与 header 精确一致。
- 未覆盖：Windows 无法执行 Android 设备 Keystore 删除、iOS 模拟器/真机 Keychain 删除及 Apple 最终链接运行；只完成对应目标编译门禁。
