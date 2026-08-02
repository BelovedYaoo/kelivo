# 当前设备自撤销专用签名

- 基线：`888c75e4`；分支：`feature/e2ee-self-revocation-native-signing`。
- 已完成：按服务端 v3 契约构造固定 145 字节规范帧，计算 SHA-256 后由设备 Ed25519 身份签名，并提供 Rust、C ABI 与 Dart 强类型创建/验证接口。
- 安全边界：没有任意帧或摘要签名入口；创建失败时清零摘要与签名输出；UUID、代次、摘要长度和 Dart FFI 时间范围均严格校验。
- ABI：secure-core ABI 从 21 升至 22，C 头文件与 ffigen 生成绑定已同步。
- 验证：protocol 75 项、native 100 项、secure-core Flutter 38 项全部通过；根项目 `flutter analyze lib test` 通过。根项目完整测试首次构建的 3 个失败均已用显式 native runner 单独复测通过。
- 集成边界：调用方仍须把 `deviceId` 和签名公钥绑定到已认证设备成员状态，并校验意图时效；本提交只负责密码学规范编码与签名验证。
