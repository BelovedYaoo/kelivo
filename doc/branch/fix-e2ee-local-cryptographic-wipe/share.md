# 本机密码学擦除协作记录

## 当前目标

- 实现 Issue #66 的安装级“移除此设备”闭环。
- 远端撤销成功后，停止后台工作并幂等删除全部账户及匿名工作区的会话、设备状态、安全槽、数据库、附件、敏感偏好和日志。
- 使用持久重置标记支持崩溃后继续；任何无法确认的删除都失败关闭，不向 UI 伪报成功。

## 进度

- Provider 已按 requested→排空业务 lease→幂等回执→confirmed→冷重启接线；响应未知复用同一 mutationId，在途登出或 dispose 不会丢弃回执。生产未注入 #51 committer，入口在写 marker 前禁用。
- 安装级共享/独占 lease、冷启动准入和两阶段 completion 已闭环；requested-only、临时 marker、冲突组合及崩溃重试均失败关闭，workspace bootstrap 只能在业务 lease 下发生。
- 偏好擦除、全部已注册账号及匿名工作区的明文备份凭据退役已接通；未知账号命名空间在删除前拒绝，Android 实机偏好耐久验证仍由 #83 跟踪。
- 安装根 Dart 递归已由 ABI18 句柄相对擦除替换：固定并复核 confirmed marker 身份，偏好清理前后各执行一次；原生失败或谎报成功但留有残余时不回退、不提交完成。
- 擦除入口以安全核心实际 capability 为准，深层服务在 unsupported 时禁止写 requested；Windows 与 Android 开放，Linux 和 Apple 在 #85 完成跨进程根身份保护前失败关闭。
- 验证：Windows native 83/83、显式隔离 Dart secure-core 28/28、本机擦除 33/33、Provider/UI 自撤销 10/10、lease 18 通过及 1 个权限跳过、明文退役 4/4；根 `lib test` 与 secure-core 包 analyze 均为零问题；Windows Debug 与 Android Debug 完整构建通过，APK 的三个 ABI 均包含安全核心和 SQLCipher 原生库。
- 最终安全复核无 P0；#51 生产撤销提交器与 requested-only 冷启动回执查询必须一并接入，#85 仍负责消除 Dart 路径到原生重新开根之间的本机同权限替换窗口。
- 未运行任何默认生产安全槽或生产安装根测试；全仓 analyze 的 755 个既有依赖诊断由 #80 跟踪。

## 协作边界

- 普通登出行为保持不变。
- 本分支不处理服务端数据重加密、附件双 epoch 或 HKDF 加固。
