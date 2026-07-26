# 协作摘要

- 目标：为 Issue #50 建立不透明记录标识与受控账户密文信封边界，避免真实实体类型/ID或伪装 Base64 明文进入 v3 transport。
- 完成：Secure Core ABI v7 使用 ARK 派生的独立子密钥执行域分离 HMAC-SHA256，生成 UUIDv4 形状的不透明记录 ID；原始 ARK 不出原生层。
- 完成：Dart 记录加密器严格编码实体键和版本化明文帧，AAD 绑定用户与同步协议；开启后重新派生记录 ID，临时明文在同步解码回调结束后清零。
- 完成：出站只能提交可信密文 put，已移除未认证 delete；入站信封和删除状态均保持显式不可信类型。wire v3、Workers 与 D1 无需修改。
- 验证：Secure Core Rust 42/42、依赖 Dart 13/13、同步协议 72/72、根项目全量 1550 通过且 19 跳过；根项目 `lib test` 分析通过。
- 边界：生产仍使用 `LocalOnlySyncWriteExecutor`，本分支不接 outbox、cursor 或领域同步。#50 的认证版本链、账户检查点与加密墓碑仍是上线阻塞，不能把服务器 revision 或 delete 当作可信状态。
