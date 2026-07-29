# 首设备恢复安全 Bootstrap

- 已新增一次性 concrete preparer：生成恢复身份、密封 epoch 1 capsule、创建并本地验证签名 genesis，再导出固定 644 字节加密恢复介质。
- 服务 origin 仅接受 `https://kelivo.bemylover.top`，固定绑定其 SHA-256；旧 workers.dev、尾斜杠和 HTTP 均失败关闭。
- 构造时接管并清零调用方恢复口令；所有 prepare 退出路径再次清零内部口令并关闭恢复句柄；未开始时可调用幂等 `close()` 主动销毁。
- exporter 只接收密文，且必须异步返回 `true`；ack 前 prepare Future 不完成，拒绝或异常时密文临时缓冲区清零。
- 验证通过：根定向 analyze、9 项行为测试；`kelivo_secure_core` 独立 analyze、27 项完整测试及 Windows release 原生构建。
- 后续接线：Android/iOS 注册层创建 preparer，并在注册外层 `finally` 调用 `close()`；二维码/恢复文件 exporter 与服务端 recovery challenge 仍由 #49 后续实现。
