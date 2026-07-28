# 分支协作记录

- 基线：`feature/e2ee-chat-runtime@f01cda8c`。
- 已通过既有 `tool/openapi/generate.ps1` 从 `kelivo-api@02dce9e` 重建附件 API、请求响应模型与序列化器，未手改生成文件。
- 已实现 create、put、commit、manifest、chunk、delete 六个强类型 POST 操作；全部强制显式完整会话令牌和 v3 头，并限制正 uint32、1000 块、4 MiB 块密文、1 MiB 清单及规范无填充 Base64URL。
- wire 请求与服务端源码一致：create 包含 `mutationId/attachmentId/keyEpoch/chunkCount/totalCiphertextBytes`；put 包含 `mutationId/attachmentId/uploadId/keyEpoch/chunkIndex/ciphertext`；commit 包含 `mutationId/attachmentId/uploadId/keyEpoch/manifestCiphertext/chunks[{chunkIndex,ciphertextBytes}]`；manifest、chunk、delete 均绑定 `attachmentId/uploadId/keyEpoch`，chunk 另含 `chunkIndex`，delete 另含 `mutationId`。
- 请求只包含协议身份、分块长度和不透明密文；不包含文件名、MIME、hash、业务 ID、明文或密钥。
- 成功响应严格校验原始 JSON 字段集合、请求身份、长度和清单连续性，修复生成器忽略未知字段的问题（Issue #823）。
- 普通同步记录的出站与入站 `keyEpoch` 校验已统一为完整正 uint32，最大值 `0xffffffff` 已覆盖真实推送与拉取（Issue #824）。
- 验证：生成 SDK `dart analyze lib` 通过；本次文件定向分析通过；同步协议测试 94/94 通过；根级 `flutter analyze` 仅复现既有 Issue #33 的 `mcp_client` 缺少 `package:test`，共 736 个连锁诊断。
