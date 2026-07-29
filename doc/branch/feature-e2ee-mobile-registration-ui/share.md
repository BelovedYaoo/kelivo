# 移动端首次账户注册

- Android、iOS 登出态可在登录与注册间切换，注册收集账号、显示名称、密码和设备名称。
- Windows、Linux、macOS 保持仅登录，页面不会渲染注册入口或显示名称字段。
- 页面复用 `CloudSyncProvider.register`，本地提交门禁覆盖 Provider 状态更新前的重复点击窗口。
- 四份 ARB 与生成本地化已同步；新增和相关回归测试均通过。
