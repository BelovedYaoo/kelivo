# Apple 偏好耐久擦除协作记录

## 控制合同

- Primary Setpoint：iOS 14+ 与 macOS 上，Kelivo 本机擦除涉及的偏好必须由应用自有持久化文件承载，并能以文件和父目录 durability barrier 证明删除完成。
- Acceptance：通过 `DurableSharedPreferencesStore` 公共合同验证写入后独立重开可见、删除后独立重开为空、写入/同步/复读失败均失败关闭，且崩溃后重试幂等。
- Guardrails：不把 `UserDefaults.remove`、进程内复读、延时或 `synchronize()` 当作耐久证明；不清理其他应用 domain/suite；不访问默认安全槽。
- Boundary：`durable_shared_preferences_store.dart`、Darwin 自有偏好原生通道、对应合同测试和平台工程注册；避开 #84/#85 正在修改的 `main.dart`、`local_cryptographic_wipe.dart` 与 secure-core ABI。
- Risks：Flutter 现有偏好调用仍落入 UserDefaults；Apple 平台无法在 Windows 环境执行 Xcode/真机验证；原子替换与父目录同步失败必须向 Dart 透传。

## TDD 场景

- Happy：原子写入后新实例读取一致；删除后新实例确认目标键不存在。
- Boundary：空存储、重复删除、Kelivo 自有键前缀与所有账号工作区键。
- Failure：临时文件写入、文件同步、原子替换、父目录同步或独立重开校验任一步失败，不得返回成功。
- State：未完成写入不覆盖旧快照；已完成删除在重启重试时保持幂等。

## 协作状态

- #84 不修改 durable preferences 合同，并要求避免其正在修改的启动与本机擦除文件。
- #85 负责安装根文件句柄与受管根删除序列，Darwin capability 当前仍失败关闭；本分支不修改 secure-core ABI。
- Apple 官方确认 UserDefaults 先更新内存、异步写盘；普通 `fsync` 也不能提供强掉电持久预期，强预期需 `F_FULLFSYNC`。`shared_preferences_foundation 2.5.6` 的 legacy remove/clear 没有耐久回执，Dart 仍无条件返回成功。
- 已确认全量 Apple `SharedPreferencesStorePlatform` 硬切到 Kelivo 自有原子 JSON；旧 `flutter.*` 或 `kelivo.account.*` UserDefaults 只尽力清理并写耐久污染标记，永久阻断到应用容器被清空。
- Dart 公共合同已完成：过滤条件透明传递、快照严格校验、原生失败透传、Apple 初始化成功后才注册；4 个测试与子包 analyze 通过。
- Darwin store 已实现原生串行队列、跨进程文件锁、同目录临时写入、`F_FULLFSYNC`、原子 rename、父目录 `fsync`、独立新文件描述符复读和崩溃临时文件清理；未知类型、畸形快照及任一系统调用失败均关闭。
- Swift 合同覆盖跨实例写删、重复删除、目录 barrier 失败重试、旧 UserDefaults 污染永久阻断和崩溃临时文件清理。当前 Windows 没有 Swift/Xcode/CocoaPods，无法执行 Apple 原生测试或编译。
- 启动失败界面已识别原生污染诊断码，四语言明确要求清空应用容器，且隐藏无效的重启操作；定向 widget 测试 4/4 与 analyze 通过。Windows 原生 hook 同时提示构建期间文件变化，未影响本切片断言，最终全量验证需在所有安全核心并行工作合并后重跑。
