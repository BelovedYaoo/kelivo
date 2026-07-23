# OPAQUE 客户端原生接口基座

- 基线：`main@f9be1da7`。
- 关联：复用 Issue #13，本分支未操作 Issue。
- 范围：`dependencies/kelivo_secure_core` 的协议核心、C ABI、Dart 封装、生成绑定、构建依赖追踪及需求驱动测试。
- ABI：版本提升至 v3，只新增注册开始/完成、登录开始/完成、状态关闭 5 个客户端 OPAQUE 导出；Windows 与 Android x64 已核对导出表。
- 秘密边界：密码只作为调用输入进入 Rust；客户端注册/登录状态仅存在于 Rust 不透明句柄表；session key 与 export key 在 Rust 内归零，均不返回 Dart，也不进入 ARK。
- 状态约束：正 63 位类型化且不复用的句柄域；注册/登录状态单次消费；active 与 in-flight 共享 64 个总上限；64 MiB Argon2 finish 全进程最多并行 1 个，许可用 RAII 释放并对计数下溢 fail-closed。
- 输入约束：密码 1 至 65535 字节，服务端消息固定长度，账户标识仅接受 RFC 4122 UUIDv4 原始 16 字节；失败输出先归零，C ABI 各输入/输出区域要求互不重叠。
- Dart：先同步消费句柄，再在复制与创建可转移缓冲区前校验；密码工作副本、原生分配和异常路径均做 best-effort 清零与释放；Argon2 在工作 isolate 执行。
- 验证：协议测试 8 项及 clippy 通过；原生测试 34 项默认并行连续 5 轮及 clippy 通过；Dart 包 analyze 与 9 项测试通过；Windows、Android x64 release 构建及 5 个允许符号的导出检查通过。
- 未覆盖平台：本分支未构建 Linux、macOS 与 iOS；它们仍复用同一纯 Rust 协议核心和 C ABI，但平台产物需在对应环境继续验证。
