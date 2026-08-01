# Apple 偏好耐久硬切总结

- iOS 14+ 与 macOS 的全部 `SharedPreferences` 已硬切到 Kelivo 自有原子 JSON，不迁移也不兼容读取旧 `UserDefaults`。
- 原生快照使用显式类型标签，严格区分 `Bool`、`Double`、`Int`、`String` 与 `StringList`；旧无类型快照、未知标签、畸形值和超过 16 MiB 的写入均在替换前失败关闭。
- 路径从 `Library` 的系统保护父目录开始，以 `openat/fstatat` 钉住 `Library`，再用 `mkdirat/openat/fstatat` 逐层建立并锚定 `Application Support` 与最终目录；统一操作入口在成功和异常退出时都会审计整条 inode 链，路径错误优先于原始业务错误，观察到任一替换后永久毒化该 store 实例。业务 barrier 不写入 `Library` 根。
- 原生写入使用串行队列、跨进程锁、固定同目录临时文件、数据文件 `F_FULLFSYNC`、原子替换、目录 `fsync`、同卷普通文件 `F_FULLFSYNC` 屏障和独立重开校验；清理失败临时文件也必须完成目录屏障。任一步失败均失败关闭。
- 检测到旧 `flutter.*` 或 `kelivo.account.*` 偏好时，先耐久写入污染标记，再尽力清理旧值，并永久阻断到应用容器被清空。
- 应用在安装门禁最前注册 Apple 耐久偏好；注册失败进入恢复失败页。恢复页已提供四语言清空应用数据指引，不再显示无效重试操作。
- Workmanager 的 headless isolate 会在创建后台同步 Runner 前独立完成耐久偏好注册；注册失败不会进入工作区或网络业务。主 isolate 也只在注册成功后构造后台调度器。
- 插件注册不再在 Flutter 主线程构造 store；首次方法调用才在专用串行 I/O 队列中惰性创建并缓存结果。
- Dart 平台合同测试 5/5、相关同步套件 120/120 通过；依赖包与根项目 `lib test` 静态分析均通过。根项目全量测试运行约八分钟未结束且无失败输出，已主动终止。
- 已编写 19 个 Darwin XCTest 场景，覆盖类型、根目录及中间路径替换、操作中替换、异常退出审计与实例毒化、屏障顺序与失败、幂等重试、写入上限、旧格式拒绝和临时文件清理；当前 Windows 环境缺少 Swift、Xcode 与 CocoaPods，Apple 原生编译、XCTest、模拟器和真机验证尚未执行。
- `fsync` 加同卷普通文件 `F_FULLFSYNC` 是 Apple 公开 API 下的最强尽力耐久语义，不承诺突然断电绝不丢失，也不等价于 APFS 或闪存物理块安全擦除；本地机密的物理不可恢复仍依赖加密与销毁密钥。Issue #86 在 Apple 构建、模拟器及真机验证完成前保持打开。
