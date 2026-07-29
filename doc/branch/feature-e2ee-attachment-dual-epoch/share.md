# 协作摘要

- Issue #52：附件身份、消息线格式、HTTP 合同、清单、加密会话和 Drift 状态已硬切为 `chunkKeyEpoch`、`manifestKeyEpoch`、`manifestRevision`。
- 下载状态采用单行 CAS 清单换代，允许代次与修订增量一致的离线前跳并拒绝回滚；连续待认证换代保留 ready candidate。
- 失败重建、资产失效和资产回收改为 `dormant` 高水位，不再删除身份行；`cleanupStagingPath` 持久回执保证暂存文件物理删除可在崩溃后幂等恢复且先于发网。
- 数据库硬切至 v23，仅在发布新安装回执前耐久删除 `upload/e2ee/staging`，不枚举或删除 `content`；冻结 schema 只保留 v23。
- 已完成 build_runner、Drift v23 schema 生成、格式化、目标分析及附件持久状态、协调器、安装门、迁移、资产 GC、schema 和协议定向测试。完整 `flutter analyze` 仍受 Issue #80 的未改动路径依赖缺失影响。
