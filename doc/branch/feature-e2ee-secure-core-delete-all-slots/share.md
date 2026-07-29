# 协作摘要

- 基线：已安全重放至 `feature/e2ee-chat-runtime@75b0342a`，跟踪 Issue #66 / #81；范围仅为 secure core 安装级全槽删除，不包含上层运行时、界面、数据库或附件擦除。
- ABI：升级至 v17，新增 `kelivo_key_slots_delete_all`，header、ffigen 绑定和 Dart `deleteAllSlots` 已闭环。
- 并发语义：创建、打开、单槽删除和全槽删除共用生命周期锁；任一持久槽句柄仍打开时，全槽删除在平台调用前返回 `SLOT_IN_USE`。
- 平台边界：Windows 通过 Known Folder 定位生产根，所有槽操作共用跨进程命名空间锁，并以 no-reparse 相对句柄删除；Android 从 `/` 逐级 no-follow 固定根 FD，锁内只用 `openat` / `unlinkat` / `renameat2`；iOS 只删除固定 service、非同步、Data Protection Keychain 的通用密码项。
- 审查修复：共享 ASCII 名称解析先拒绝 Unicode，消除字节切片 panic；Android 每次枚举使用固定根下独立目录描述，避免共享偏移导致最终复核假空；Windows 目录查询解析完整校验固定头、长度和未对齐读取。
- 测试隔离：Windows `cfg(test)` 永不解析生产根；Dart 槽测试必须经 marker + compile-time define 启用 feature-only 随机测试库，遗漏入口在任何 FFI 槽操作前失败。正式 release 不包含测试 ABI。
- 验证：native 75 项、测试库生命周期用例、Windows 默认/测试 feature 严格 Clippy、Android 三目标及 ARM64 测试目标、iOS 三目标、依赖包全量和根改动文件 Flutter analyze 均通过；显式 Dart 测试库的依赖包与根调用链用例通过；正式 release 55 项 header/导出一致且无测试符号，测试 feature 仅增加两个作用域符号。
- 未覆盖：根项目全量 analyze 受既有子依赖缺少 `test` / `pigeon` 开发依赖阻断；Windows release marker 负向构建卡在 VS `CompilerIdCXX`、未到 hook；Android Keystore/祖先换链和 iOS Keychain 尚未在真机或模拟器执行。所有测试均未访问默认生产槽。
