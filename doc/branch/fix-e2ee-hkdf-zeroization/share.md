# 协作摘要

- 目标：解决 Issue #70，仅清理设备与附件 HKDF 派生路径中调用方可控的中间密钥副本。
- 验收：现有固定向量与错误边界保持不变；Rust format、严格 Clippy、protocol/native 测试及依赖 Flutter 分析通过。
- 边界：不修改公开 ABI、wire、双 epoch、数据库或备份 UI；不声称能清理 VM、分配器或密码库内部不可控副本。
- 完成：恢复、配对认证、账户信任种子及附件包装/分块统一使用显式单块 HKDF-SHA256 helper；自有 PRK 使用 `Zeroizing`，最终键直接写入既有清理目标，protocol 已移除 `hkdf` 直接依赖。
- 验证：RFC 5869 红绿测试、protocol 61+1+4、native 66、Flutter 27 项测试，以及 protocol/native 严格 Clippy、Flutter analyze 全部通过。
- 残余：Dart 仅获得公钥或密文，不持有原始派生键；HMAC/HPKE 库内部与 VM/分配器副本不受调用方控制，不纳入显式清零承诺。native crate 的数据库、记录与设备状态仍有独立 HKDF 路径，本提交不扩展 Issue #70 的 protocol 范围。
