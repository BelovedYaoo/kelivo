# E2EE 设备状态认证绑定

- 目标：解决 Issue #36，使安全核心在 AEAD 认证设备状态后返回 binding，解除重新登录前的循环依赖。
- 硬切：未发布 ABI 不保留兼容入口；Dart 不解析或暴露认证前的 clear metadata。
- 验收：失败输出全部复位且不泄漏句柄；identity-only 与完整状态返回精确的设备、账户和 epoch 绑定。
- 实现：ABI v5 以 48 字节版本化 struct 返回认证后的设备/账户 binding；旧的 expected 参数已硬删除，Dart 只在 Native 成功后构造不可变 binding。
- 失败边界：空输出指针、空 blob、错误长度与 AEAD 篡改均不会发布 binding 或句柄；Dart 对未知 struct size/flags、非规范空账户和 ARK 标志失配均关闭句柄后失败。
- 验证：Native 39 项、严格 Clippy、Windows release、C header 语法、Dart 11 项与 analyze 已通过；Android arm64 debug APK 构建通过，且 APK 已确认包含 `lib/arm64-v8a/libkelivo_secure_core.so`。
