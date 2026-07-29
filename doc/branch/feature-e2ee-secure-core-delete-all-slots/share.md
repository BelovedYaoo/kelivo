# 协作进度

- 基线：`feature/e2ee-chat-runtime@77b10f62`，跟踪 Issue #66。
- 范围：仅实现 secure core 安装级全槽删除 C ABI、Dart API、平台后端与需求驱动测试；不修改上层擦除运行时或界面。
- 安全约束：与创建、打开、单槽删除串行；任一 slot-backed 句柄存活时整体拒绝；缺失幂等；无法确认删除时失败关闭。
- 平台决策：Android 同批删除全部槽文件、遗留临时文件和共享 Keystore 主包装密钥，使已删除密文即使被恢复也不可解密；iOS 删除固定 service 下全部 Keychain 项；Windows 仅通过已验证目录句柄枚举并逐项 no-reparse 删除。
- #81 测试隔离：曾有 C ABI 成功路径测试误触 Windows 默认槽目录；已冻结所有测试与构建，事故细节已上报。
- 静态修复：`cfg(test)` 下 `default_store()` 只接受显式随机临时目录作用域，缺少作用域时返回 `InternalState`，不会回落 `%LOCALAPPDATA%`；真实生产根解析仅在 `cfg(not(test))` 编译。
- 零生产 I/O 门禁：测试构建的同名生产根解析函数仅累计禁止调用并返回 `InternalState`；两个有效 C ABI 槽测试前后只断言调用计数为零，不读取环境变量、生产路径、目录或条目。
- 审计：其余 slot C ABI 用例仅覆盖空指针、长度、策略等平台调用前失败边界，或只在 unsupported 平台编译；Windows 后端单测直接构造每用例临时 `SlotStore`。
- 冻结边界：尚未运行任何修复后的测试、构建或应用，需主任务审查隔离实现后再解除。
