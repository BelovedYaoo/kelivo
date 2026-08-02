# 当前设备自撤销客户端

- 基线 `889aa0b4`；完成 create/status/cancel/list 强类型传输、独立 continuation bearer、完整请求绑定、严格 oneOf/额外字段门禁、本地过期检查、同安全头列表和未信任终态回执结构校验。
- 覆盖响应丢失重放、401 不回退完整令牌、pending/expired/superseded/cancelled/confirmed、公共绑定和 completion 篡改、列表 0/64/65/乱序/混合安全头、同毫秒多段恢复及二进制不可变。
- 验证：改动文件定向分析无问题；安全包装下完整同步协议测试 182/182 通过；最终列表时钟用例通过；`git diff --check` 通过。
- 上层硬门禁：协调前验证设备 intent 签名并与本地可信 current head 对照；接受完成态前验证 revoke-rotate/recover-resume 清单签名链、最终 issuer、proof digest 和 completion signature。
- 后续依赖：rotation commit 仍需成对接入 `selfRevocationMutationId` / `selfRevocationIntentDigest`；请求侧设备身份专用签名 ABI 仍需实现。
