# E2EE 配置数据面协作摘要

- 跟踪 Issue：https://github.com/BelovedYaoo/kelivo/issues/50
- 已实现十类配置实体和八个偏好单例的严格规范 payload；身份字段必须匹配 `SyncEntityKey`，未知类型、额外字段、非法数值、Unicode 与非规范 JSON 均失败关闭。
- 已覆盖当前 Provider、Assistant、Memory、World Book、Quick Phrase、16 种搜索服务、8 种网络 TTS、4 种 MCP transport、Instruction Injection 和偏好 JSON 契约；API Key、使用状态、轮询指针与代理凭据均完整保留。
- `modelOverrides`、MCP 参数默认值和 MCP JSON Schema 是现有开放扩展点，只允许任意规范 JSON；其余对象使用精确字段集合。
- `E2eeConfigSyncAdapter` 只读写 schema 16 SQLCipher Vault：缺失行生成墓碑，远端值按依赖稳定排序后在 Pull 外层事务内直写，不产生 outbox 回声。
- 未接入 Provider、SharedPreferences、`main.dart` 或附件，不恢复旧明文协议、旧存储和兼容分支。
- 验证：目标 `flutter analyze` 通过；`app_database_constraints_test.dart` 全部 62 项通过。
