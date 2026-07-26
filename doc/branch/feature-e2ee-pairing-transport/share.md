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
