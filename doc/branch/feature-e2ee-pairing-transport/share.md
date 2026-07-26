# 协作摘要

- 已从最新 OpenAPI 重新生成 Dart 客户端，硬删除旧密码认证与旧设备会话接口。
- 已实现 OPAQUE 四路由和设备配对五路由的强类型传输；完整会话令牌与设备引导令牌不可混用，鉴权逐请求显式注入。
- 固定长度二进制统一使用规范、无填充 Base64URL；响应数据防御性复制为不可修改视图；2xx generated 反序列化失败归类为不可重试的无效响应。
- 已将设备列表与撤销切换到 trusted-device 路由；注册、登录认证和配对消费响应均保留当前 `keyEpoch`。
- 验证：generated 包分析通过；三文件定向分析通过；协议测试 17/17 通过；`git diff --check` 通过。
- 集成边界：未修改 Provider/UI/ARB。Provider 仍保留旧密码入口，合并后需由后续任务迁移到 OPAQUE；设备身份启动闭环由 Issue #36 跟踪。
- 已将账号工作区持久会话硬切到 E2EE 契约：token 使用 `CloudSyncFullSessionToken`，metadata v2 持久化 `tokenExpiresAt` 与正 uint32 `keyEpoch`，旧 metadata 版本直接拒绝；token 仍仅以原始值进入加密存储，恢复后立即解析。
- 会话定向分析通过；新增/相邻会话用例 12/12 通过。runtime 全文件测试因既有 runner 五分钟无输出而超时，未发现失败输出。
- 集成残余：`cloud_sync_provider_content_gate_test.dart:235` 仍使用旧会话构造（缺少 `tokenExpiresAt`、`keyEpoch` 且 token 为 String）；同文件 fake client 还残留新版账户客户端接口未实现及旧 `setToken(String?)`，交由 Provider 集成任务统一处理。
- 新增 `E2eeAccountAuthentication` 深模块接口及生产实现：移动首设备注册在服务端完成前先耐久化 full device state；登录严格区分已认证与待批准设备，并校验本地账户、设备和 key epoch 绑定。
- 设备状态 key slot 由规范服务地址与登录名经域分离 SHA-256 截断派生；缺失状态仅初始化 identity-only，已有 blob 的 slot 缺失或 AEAD 失败均直接失败关闭。
- 密码缓冲区由认证模块取得所有权并在所有退出路径清零；OPAQUE、持久 key、identity、ARK 句柄在成功和失败路径统一关闭，服务端身份不匹配时清除已接管 token。
- 认证验证：认证/传输协议测试 23/23 通过，认证模块与协议测试定向分析无问题。真实 OPAQUE 成功组合门禁由 Issue #38 跟踪；映射盘临时目录问题由 Issue #37 跟踪。
