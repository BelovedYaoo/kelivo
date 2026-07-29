# 协作摘要

- 基线：`feature/e2ee-chat-runtime@77b10f62`，跟踪 Issue #66；范围仅为 secure core 安装级全槽删除，不包含上层运行时、界面、数据库或附件擦除。
- ABI：升级至 v17，新增 `kelivo_key_slots_delete_all`，header、ffigen 绑定和 Dart `deleteAllSlots` 已闭环。
- 并发语义：创建、打开、单槽删除和全槽删除共用生命周期锁；任一持久槽句柄仍打开时，全槽删除在平台调用前返回 `SLOT_IN_USE`。
- 平台边界：Windows 只枚举固定 Kelivo 槽目录并以 no-reparse 相对句柄删除；Android 只处理固定槽目录，先删除并复核共享 Keystore 包装密钥，再清理已预检槽文件；iOS 只删除固定 service、非同步、Data Protection Keychain 的通用密码项。
- 测试隔离：Windows 测试构建不能解析生产槽根；C ABI 成功路径必须显式进入随机临时目录作用域，并断言生产根解析次数始终为零。
- 验证：native 71 项测试、Windows 严格 Clippy、Android 三目标及 iOS 三目标 `cargo check`/严格 Clippy、依赖包 `flutter analyze`、Windows release 55 项头文件/导出一致性、Android 桥接类 `javac -Xlint:all -Werror` 均通过。
- 未覆盖：按安全约束未运行会调用生产槽 FFI 的 Dart 测试；Android Keystore 删除和 iOS Keychain 删除尚未在真机/模拟器运行验证。
