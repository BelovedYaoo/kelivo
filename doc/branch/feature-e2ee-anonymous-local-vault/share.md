# 匿名 SQLCipher LocalVault 底座

## 完成摘要

- 基线：`feature/e2ee-chat-runtime` 的 `6b6106f6`；Issue 沿用 #13。
- 匿名工作区已硬切到 `.kelivo-workspaces/local/data`，与账号 A/B 的目录、配置前缀和 `workspaceKey` 隔离。
- 登录与普通退出只切换活动工作区，不复制、合并或删除匿名/账号 Vault。
- 安装根已退役为数据库目录：主库、WAL、SHM、journal 与安装回执无条件删除；当前匿名和账号密文 Vault 保留。
- LocalVault 路径采用与账号工作区一致的所有权校验，目录链接或异常类型会失败关闭。
- Issue #72 已修复：安装根首次信任锚改为词法绝对路径，根或任一祖先存在链接、junction、重解析偏移时失败关闭；破坏性明文清理前会重新验证安装根。
- 现有安全核心接口无需改动：Dart 仅传槽位标识、数据库标识和 SQLite 句柄；平台随机主密钥不进入 Dart，派生密钥由 Rust `Zeroizing` 管理。

## 验证结果

- 工作区与数据库门禁完整定向测试：123 项通过。
- 安全核心原生测试：52 项通过，包含 Windows DPAPI 槽位与 SQLCipher 回调。
- 四个改动文件定向 `flutter analyze`：通过。
- 原匿名 LocalVault 基线的 Windows release 构建：通过，产物 `build/windows/x64/runner/Release/kelivo.exe`。
- #72 Windows 回归：祖先 junction、安装根 junction 与普通缺失尾部目录共 3 项通过；完整工作区测试 105 项通过，改动文件定向分析通过。
- #72 修改后的 Windows release 构建两次停在 `MSBuild INSTALL.vcxproj` 等待态：一次 10 分钟超时，一次禁用节点复用后仍无编译子进程；已清理全部残留构建进程，未取得新的平台产物。
- 全仓 `flutter analyze` 仍受既有本地依赖开发依赖缺失影响：`mcp_client` 缺少 `package:test`，`workmanager_platform_interface` 缺少 `pigeon`。

## 范围边界

- 不含附件、远端备份、UI、偏好 secrets 或 #66 hard reset。
- 不保留旧安装根数据库兼容读取或迁移路径；旧本地数据库数据会按已确认策略永久删除。
- 链接安装根拒绝属于主动破坏性兼容变更；Dart 路径验证与删除之间仍不是同一 OS 句柄事务，无法承诺抵御具备本机文件系统写权限的并发竞态替换。
- 本次未执行 Android/iOS 实机或平台构建；iOS 最低版本仍保持 14。
