# 协作摘要

- 目标：为附件下载实现与数据库 `stagingPath`、`confirmedPlaintextBytes` 单一真源匹配的可崩溃恢复文件存储边界。
- 范围：仅修改 `e2ee_attachment_file_store.dart` 与现有 `cloud_sync_client_protocol_test.dart`；不修改数据库、schema、运行时或协调器。
- 基线：`d1b49677`。
- 已完成：下载 staging 硬切为按 `attachmentId/uploadId/keyEpoch` 隔离的单一 `plaintext.part`；旧逐块下载密文定位已移除。
- 已完成：创建/打开只接受精确持久路径；文件短于 DB 确认值失败，长于确认值经 flush 与完整持久性屏障后截断。
- 已完成：单块追加要求文件长度精确等于 expectedOffset；写后 flush 与完整文件屏障，单块大小受协议上限约束。
- 已完成：发布前流式核对总长度与 SHA-256，同账户卷内无覆盖重命名到 `content/<sha256>`；既有 final 仅在长度、摘要完全一致时幂等成功。
- 已完成：平台与内存 adapter 均覆盖多块、零字节、尾部崩溃、错 offset、短文件、篡改、final 冲突、异常路径及重启幂等。
- 验收：目标 analyze 无问题；完整 `cloud_sync_client_protocol_test.dart` 98 项全部通过。
