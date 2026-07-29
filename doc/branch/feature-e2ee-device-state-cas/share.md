# E2EE 设备状态 CAS

- `DeviceStateBlobStore` 已硬切为版本化读取与 CAS 写；令牌由私有构造并绑定 locator、generation、slot 与完整 state frame SHA-256，不暴露状态字节或密钥。
- CAS 比较与 A/B manifest 发布位于既有 Windows 独占句柄 / POSIX flock 临界区；冲突发生在任何清理或发布前，同字节幂等返回原令牌且不推进代际。
- 生产无条件 `write` 已删除；注册、恢复注册、设备配对与回滚均消费打开状态时取得的精确令牌，只有首次身份创建允许预期不存在。
- 覆盖首次创建、重复创建、陈旧令牌、跨 locator、同字节幂等、删除/损坏、崩溃重试与临时文件清理、真实双 isolate 竞争；原有 tombstone、A/B 崩溃和 Windows 路径测试继续复用 CAS 测试 setup。
- 定向 Dart 分析通过。Flutter 测试未跑完：本 worktree 的 sqlite3 native-assets hook 长时间无输出，相关孤儿进程已清理；合并后需在无并行 hook 时串行复验 workspace、同步协议和内容门禁测试。
- 跟踪 Issue #51；本分支不实现 data-rekey 执行器。
