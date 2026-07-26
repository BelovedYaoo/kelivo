# E2EE 设备状态原子存储

- `DeviceStateBlobStore` 以 A/B state + manifest 原子发布固定 188 字节不透明 KDST；损坏当前代时显式失败，不回退旧代。
- 删除先发布带代际和摘要校验的持久 tombstone，随后分阶段清理 manifest、state 和自有临时文件；读绝对优先 tombstone，重建仅在新 state 与 manifest 持久化后清除它。
- 同一 locator 的读、写、删统一使用 OS 锁：Windows 为独占 `CreateFileW` 句柄并检查 reparse tag，POSIX 为 `open(O_NOFOLLOW)` 与 `flock(LOCK_EX)`；所有句柄和文件描述符均在 `finally` 释放。
- 临时文件使用 128 位随机名、独占创建和严格模式清理；代际在加一前检查上限。纯 Dart 最终 rename 对同用户恶意非守约进程的持续路径竞态仍是明确残余边界，崩溃恢复与守约并发客户端已闭环。
- Windows 验证：设备状态 15/15、整份账号工作区 63/63、变更文件定向分析通过。仓库全量测试 runner 六分钟无用例输出后终止；全量分析被既有 `dependencies/mcp_client` 缺少 `package:test` 基线问题阻断。Linux、Android、macOS、iOS 未做实机锁与持久性验证。
