# 协作进度

- 跟踪：Issue #90，Android 全新安装首次 `key_slot_create` 返回 `ioFailure`。
- 基线：`feature/e2ee-chat-runtime@d697d4c0`。
- Primary Setpoint：修复安全槽硬切回归，使 Android 新安装可通过公开接口创建并持久读取隔离安全槽。
- Acceptance：先以公开 FFI/应用进程接缝稳定复现；修复后覆盖首次创建、进程重开、并发与失败路径，并完成 Android 原生测试、Flutter 定向测试、Debug APK 和全新隔离 AVD 验证。
- Guardrails：不得访问既有 AVD 或默认安全槽；不得添加回退、吞错、路径放宽或降低 Windows/Linux 安全语义。
- Boundary：`dependencies/kelivo_secure_core` 的 Android 安全槽实现、公开绑定及必要的现有测试入口。
- Risks：Android Keystore/文件槽两阶段提交次序、全新目录创建权限、并发初始化竞态。
- 根因：Android 沙箱路径祖先通常只有穿越权限，且 `Context.getDataDir()` 返回的 `/data/user/0/<package>` 包含系统管理的别名。硬化后的逐级 `O_RDONLY | O_NOFOLLOW` 打开会先因祖先不可读失败；改用 `O_PATH` 后，又会在 `/data/user/0` 别名处因拒绝跟随链接返回 `ENOTDIR`，因此尚未进入 Keystore、加锁或写盘阶段便映射为 `ioFailure`。
- 修复：Rust 仅以 `O_PATH` 穿越祖先，最终槽根仍以 `O_RDONLY | O_NOFOLLOW` 打开供锁、枚举和耐久化；Java 只规范化系统托管的应用数据根，再拼接经过父子关系校验的 `no_backup` 名称和固定槽路径。应用可写的 `no_backup` 及其后代仍由 Rust 逐级拒绝链接，不放宽硬化边界。
- 验证：隔离 API 36 AVD 上先稳定复现红色失败；修复后首次创建、读写更新、删除、占用删除失败、缺失槽失败及同槽并发均通过。跨两次应用进程验证保持同一 UID、PID 变化，并成功解封上一进程密文。原生测试 75/75、账号工作区测试 115/115、Android Rust 目标检查、定向 `flutter analyze` 与 Debug APK 构建均通过。
- 兼容：`/data/user/0/<package>` 与 `/data/data/<package>` 指向同一 Android 沙箱，不改变槽文件位置、格式、FFI 或密钥语义，无需迁移；Windows/Linux 实现未改动。
- 当前：功能闭环完成，等待合并后关闭 Issue #90。
