# 分支协作记录

## 完成摘要

- 首设备 pending 硬切为 v3，密文帧持有 644B 恢复介质；旧版或损坏事务只允许显式丢弃，不做迁移。
- 新增与完整 pending 信封 SHA-256 绑定的 append-only 导出确认标记，严格执行“保存 pending、导出、保存确认、安装状态、网络提交”。
- 新增显式继续/丢弃入口：待导出事务可继续或丢弃，已确认事务只能继续，普通注册不会消费新的恢复口令覆盖旧事务。
- 恢复口令与账户密码按实际 UTF-8 字节比较，受控编码与恢复介质缓冲区均在所有退出路径清零。
- 四份 ARB 已同步并生成本地化代码；移动端注册与恢复介质 UI 已接入。
- 已通过 7 个纯协调器/字节测试、8 个 fake Provider/UI 注册测试、4 个恢复介质导出页测试；`flutter analyze lib test` 全绿。
- 仓库级 `flutter analyze` 仍受既有 path dependency 开发依赖缺失阻断：`mcp_client` 缺 `package:test`，`workmanager_platform_interface` 缺 `package:pigeon`。
- 未运行任何会调用默认安全槽的 FFI 测试。
