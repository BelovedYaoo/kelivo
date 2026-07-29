# 协作摘要

- Issue #52：附件身份、消息线格式、HTTP 合同、清单、加密会话和 Drift 状态已硬切为 `chunkKeyEpoch`、`manifestKeyEpoch`、`manifestRevision`。
- 下载状态采用单行 CAS 清单换代，支持离线跨代，拒绝回滚与旧租约；旧清单认证材料和未完成暂存状态会被清空。
- ready 文件只作为候选保留，新清单认证和本地内容哈希均通过后才复用；候选期间受资产 GC 保护，未知路径与 I/O 错误保持失败关闭。
- 已完成 build_runner、v22 冻结 schema 生成、目标分析以及附件持久下载、协调器、schema 和协议定向测试。最终自审后的 Flutter 复跑受本机 Flutter 工具 VM 挂起影响，目标 `dart analyze` 通过。
