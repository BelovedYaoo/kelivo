# QR v2 服务绑定与本地取消

## 控制契约

- 目标：二维码协议硬切 v2 并绑定规范化服务 origin；取消时优先销毁本地 pending pairing secret。
- 验收：公开 codec 与配对取消入口覆盖成功、非法输入、跨服务、离线、幂等和竞态。
- 边界：不实现成员清单提交协调器、确认 UI 或恢复 UI。

## 进度

- QR 帧已硬切 v2，加入规范 HTTPS service origin、固定保留字段和严格长度；v1、HTTP、尾斜杠、规范化差异及未知字段均失败关闭。
- 扫码批准在打开设备状态或发网前先解码并核对当前服务 origin。
- 取消会缓存同一 Future，先中止轮询、清零 QR payload 并同步关闭 Rust pending handle，再请求服务端；远端失败仍向上抛出。
- 纯 QR 45 项通过；取消红绿测试已证明旧顺序问题及修复结果。
- 测试暴露默认 Windows SlotStore 隔离事故，事实已补充至 #81；在显式临时 SlotStore 接入前不再运行真实槽集成测试。
