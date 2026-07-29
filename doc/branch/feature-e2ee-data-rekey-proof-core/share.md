# 数据重加密完成证明安全核心

- 目标：为 data-rekey v2 固定 270 字节 canonical frame 增加当前设备身份 Ed25519 专用签名与严格验签接口。
- 边界：仅修改 `dependencies/kelivo_secure_core` 的协议、Native ABI、C 头、Dart FFI 与相关测试；不实现网络 executor，不修改附件代际模型。
- 约束：设备私钥不得离开原生不透明句柄；不得暴露通用原始签名接口；验签必须沿用现有严格 Ed25519 规则。
- 完成情况：已实现固定帧 canonical 校验、设备身份签名、严格验签、Native ABI v16、Dart FFI 与跨语言固定向量测试。
- 验证：协议层和 Native 层测试、Clippy、依赖自身 `flutter analyze` 与 `flutter test` 已通过；根仓库测试被 sqlite3 下载 TLS 握手失败阻断，根仓库分析范围问题已登记为 Issue #80。
- 后续边界：网络 executor、身份/ARK 租约与附件代际模型仍由后续分支处理。
