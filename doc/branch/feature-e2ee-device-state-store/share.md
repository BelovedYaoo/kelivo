# E2EE 设备状态原子存储

- 已完成 `DeviceStateBlobStore`：以规范化服务地址和登录名的域分离 SHA256 摘要定位安装级状态，磁盘路径不包含原登录名。
- 每个定位独立维护 A/B 状态帧和 A/B manifest；固定 188 字节 KDST 仅作为不透明载荷，manifest 发布是唯一提交点。
- 写入按“撤销非当前 manifest、持久化新 slot、发布新 manifest”排序；中断不会把半写 slot 作为 current，当前发布数据损坏会显式报错且不回退旧代。
- 删除先校验全部自有路径，再持久化撤销 manifest 后清理 slot，并同步相应目录；不同身份互不影响。
- Windows 上整份 workspace 测试 54/54 通过，变更文件定向分析通过。根目录全量分析受既有 `mcp_client` 测试依赖解析错误阻断；Linux、macOS 未做平台持久性实机验证。
