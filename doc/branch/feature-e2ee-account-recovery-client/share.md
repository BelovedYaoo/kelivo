# 协作记录

## 目标

- 完成移动端账户恢复客户端闭环；桌面端只允许登录。
- 以恢复介质中的 genesis 为唯一信任锚；恢复私钥、ARK 和明文 nonce 不进入 Dart。

## 已完成

- 稳定 OpenAPI wire 已接入 challenge、冻结历史、授权、状态查询和 resume/replacement 成员提交。
- 授权协调器严格验证冻结历史与链头，持久化 `challenged -> proofReady -> authorized`，并支持授权回执丢失后安全接管。
- checkpoint 已硬切固定二进制 v3，密文槽上限 64 KiB，可原子保存完整 prepared 请求和严格绑定的 committed 回执；旧版本不迁移。
- 成员提交协调器只发送 checkpoint 中的 prepared 请求；成功回执先 CAS 持久化再返回，已 committed 本地短路，token 到期或响应失败时不改写 prepared，并可收敛同效并发回执。
- 工作跟踪使用 Issue #49；服务端 challenge 修复记录在 API Issue #32。

## 剩余依赖

- 实现 Native ABI19 单次 proof 事务和 resume/replacement 准备；不得增加 Dart 降级路径。
- 将成员提交后的 data-rekey 执行器与同一耐久 checkpoint 串联，完成中断续传和最终清理。
- 最后接入 Android/iOS 二维码与恢复文件入口；Native 生产适配器未就绪前，UI 不得宣称恢复可用。

## 协作边界

- 不部署，不触碰默认安全槽，不修改 ABI18 擦除实现。

## 验证

- `flutter analyze lib test`：通过。
- 安全核心测试包装器运行 `e2ee_account_recovery_authorizer_test.dart`：11 项全部通过。
