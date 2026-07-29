# 全工作区旧明文远端备份凭据退役

- Issue：#83，P0。
- 基线：`feature/e2ee-chat-runtime@82d1c90b`。
- `AccountWorkspaceRuntime` 现从固定安装根枚举匿名及 `accounts/<64位小写hex>/data` 工作区；任一陌生、缺失或重解析拓扑都会整体失败。
- 退役直接使用 legacy `SharedPreferencesStorePlatform` 空前缀原始枚举；Android 因此走 `FlutterSharedPreferences` 与同步 `commit()`，`remove == false` 会失败关闭。
- 删除集合仅由合法前缀与 7 个历史 WebDAV/S3/提醒键的精确笛卡尔积构成；未知账号前缀在任何删除前失败，无关和相似键保留，重复执行幂等。
- 启动在 workspace bootstrap 后把同一 runtime 交给安装级退役；无迁移、无兼容回退、未恢复远端上传能力。
- 验证：退役测试 7/7；runtime happy/boundary 2 项分别通过；5 个改动文件定向 `flutter analyze` 无问题。`R:` 临时盘满后仅把测试 TEMP 改到 `C:`，未触碰默认密钥槽。
