# 数据重加密规范字节核心

- 目标：在 Dart 客户端严格复现 data-rekey v2 的冻结源、暂存集合、完成证明与证明摘要规范字节。
- 边界：仅新增独立 wire 模块与行为测试；不修改数据库、执行器、附件双代次或 `CloudSyncClient`。
- 基线：`76e825210345db2832032cbf61dbab1398b48530`。
- 完成：实现 source header、77B 记录帧、`96+44*n` 附件帧、两种 84B staged 帧、规范排序与 SHA-256 聚合、270B completion 帧及 proofDigest。
- 完成：UUID v4、uint32、JavaScript 安全 uint64、摘要长度、数量/nullable cursor、分块连续性与唯一排序键均严格校验；二进制输入复制且公开结果不可变。
- 固定向量：completion 与安全核心逐字一致；source/staged/proofDigest 及空集合摘要与服务端 TypeScript 实现逐字一致。
- 验证：`dart format`、定向 `dart analyze`、定向 `flutter analyze` 与 15 项 `flutter test` 均通过。
- 约束：UUID、uint32/uint64、摘要、计数及 nullable cursor 严格校验；二进制输入必须复制，摘要仅由客户端本地重算。
- 后续：由 data-rekey 持久执行器将传输 DTO 转换为本模块类型并使用本地重算结果；本分支不接入 DB、executor、附件双代次或 `CloudSyncClient`。
