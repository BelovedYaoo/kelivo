# 自撤销验证摘要输出修正

- 基线：`3f040de8`；分支：`fix/e2ee-self-revocation-verify-output`。
- 已完成：verify 移除调用方摘要输入，由 Rust 重建 145 字节 v3 帧、计算 SHA-256、严格验签并返回固定 32 字节摘要。
- ABI：Native ABI 升至 23，C 头与 ffigen 生成绑定同步；独立 `server_wasm` ABI 保持 2。
- 失败边界：字段或签名错误、非法输入与短缓冲均预先清零摘要输出及长度；Dart 只接收签名并返回不可变摘要，不实现帧或哈希。
- 验证：protocol 75 项、native 100 项、secure-core Flutter 38 项全量通过；收紧后 targeted Native 1 项和 Flutter 2 项复测通过；依赖与根项目 `lib/test` 静态分析通过。
