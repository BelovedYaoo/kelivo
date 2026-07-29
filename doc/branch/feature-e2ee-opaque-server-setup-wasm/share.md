# feature/e2ee-opaque-server-setup-wasm 分支协作摘要

## Mini Control Contract

- Primary Setpoint：通过受审计的协议 crate 为 server Wasm 增加真实 OPAQUE ServerSetup 生成接口，供生产运维工具使用。
- Acceptance：接口只接受 32 字节随机种子并返回固定 144 字节 wire object；Rust 测试、Wasm 构建与 ABI 校验通过，服务端可加载并验证结果。
- Guardrails：不使用固定向量、不手拼 opaque-ke 序列化、不增加随机回退、不打印秘密、不修改 native device_core 或 Flutter 业务。
- Boundary：`dependencies/kelivo_secure_core/server_wasm` 及其生成物协作信息；服务端 artifact 复制在 kelivo-api 独立分支完成。
- Risks：ABI 变更要求服务端封装与 manifest 同步，输出句柄必须沿用所有权转移与失败清理约定。

## 进度

- 已从 `feature/e2ee-chat-runtime@d1ae65e` 建立隔离 worktree。
- 已登记 Issue #59。
- ABI 已升级为 v2，新增 `kelivo_opaque_server_setup_generate`：单次消费 32 字节宿主随机种子，调用协议 crate 生成固定 144 字节 ServerSetup 输出句柄。
- 已通过 Rust 1.91.0 下 12 项测试、`cargo fmt --check`、零警告 clippy 与 `wasm32-unknown-unknown` release 构建；生成模块无 imports，新增导出集合符合预期。
- 后续由 `kelivo-api` 运维分支更新并验证 Wasm artifact、manifest 与 TypeScript 封装。
