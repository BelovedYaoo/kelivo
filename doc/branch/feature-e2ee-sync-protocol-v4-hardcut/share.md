# feature/e2ee-sync-protocol-v4-hardcut 协作记录

- 关联 Issue：#50；基线为 `feature/e2ee-chat-runtime@888c75e4`。
- 客户端账户记录 AAD 与记录、附件、data-rekey 请求头已统一硬切协议 v4，不保留 v3 服务端兼容或静默回退。
- 开发期 v3 AAD 密文由当前记录加密器显式认证拒绝，不迁移旧本地测试状态。
- 回归覆盖记录版本错配以及 push、pull、snapshot、附件六类操作和 data-rekey 七类操作的 v4 请求头。
- 验证：相关协议测试 `186/186` 通过；三个相关文件定向 `flutter analyze --no-pub` 通过。
