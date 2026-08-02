# 分支协作摘要

## 完成内容

- 安全核心 ABI 升至 21，账户恢复 prepare 额外返回固定 260 字节 continuation。
- continuation 由安全槽主密钥独立派生的 HMAC 密钥认证，绑定完整状态、精确裁剪候选摘要和恢复设备签名公钥。
- 激活已硬切为 continuation、状态绑定、精确候选和 data-rekey 完成证明，不再依赖进程内 recovery execution；execution 关闭或进程重启后仍可继续。
- Native、FFI 与 Dart 公共 API 已同步，临时 Native/Dart 敏感副本在成功和失败路径均清理。
- 已覆盖错误 prepare 输入、错误密钥、候选/continuation/状态/证明篡改、重复激活和失败输出清零。

## 验证

- `cargo check` 通过。
- Native 默认完整测试 98 项通过；恢复定向回归通过。
- `cargo clippy --all-targets --all-features -- -D warnings` 通过。
- 安全核心 Flutter 测试 36 项通过，`flutter analyze --no-pub` 通过。
- App 账户恢复适配器相关测试 3 项通过，相关范围分析通过。
- 根仓库完整分析仍受既有本地依赖测试/生成代码错误阻断，与本分支改动无关。
