# Apple 偏好耐久擦除总结

- iOS 14+ 与 macOS 的全部 `SharedPreferences` 已硬切到 Kelivo 自有原子 JSON，不迁移也不兼容读取旧 `UserDefaults`。
- 原生写入使用串行队列、跨进程锁、同目录临时文件、`F_FULLFSYNC`、原子替换、父目录同步和独立重开校验；任一步失败均失败关闭。
- 检测到旧 `flutter.*` 或 `kelivo.account.*` 偏好时，先耐久写入污染标记，再尽力清理旧值，并永久阻断到应用容器被清空。
- 应用在安装门禁最前注册 Apple 耐久偏好；注册失败进入恢复失败页。恢复页已提供四语言清空应用数据指引，不再显示无效重试操作。
- Workmanager 的 headless isolate 会在创建后台同步 Runner 前独立完成耐久偏好注册；注册失败不会进入工作区或网络业务。主 isolate 也只在注册成功后构造后台调度器。
- Dart 平台合同测试 4/4、恢复页 widget 测试 4/4、偏好擦除测试 7/7 通过；相关静态分析通过。
- 当前 Windows 环境缺少 Swift、Xcode 与 CocoaPods，Apple 原生编译、XCTest、模拟器和真机验证尚未执行；在 Apple 环境验证前 Issue #86 应保持打开。
