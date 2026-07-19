# sync/upstream-sqlite 协作摘要

- 关联 Issue：BelovedYaoo/kelivo#1、#5、#6、#9、#10、#11、#12。
- 分支：`sync/upstream-sqlite`；定制基线：`main@2a3c7732`；上游目标：`upstream-main@16e3b21d`。
- 已合入上游 Drift/SQLite schema 12、聊天时间线、恢复流程、分页与搜索，并保留云同步 v2、定制界面和本地签名配置边界。
- 已消除启动资源维护、导入事务和附件同步的死锁或竞态；覆盖恢复、批量清空和外部覆盖导入具有显式本地权威语义，普通导入仍保持增量语义。
- 已完成云账号工作区隔离：聊天、配置、数据库、缓存、附件、同步状态和未来密钥命名空间均按账号隔离；账号切换必须冷重启，匿名数据不自动复制或上传。
- 生产云同步服务硬切为 `https://kelivo.bemylover.top`：登录页不可编辑服务地址，生产客户端不可注入其他域名或跟随重定向，非官方历史会话在业务存储绑定前失效；废弃 Workers 域名全仓零匹配，`last-base-url` 仅保留为启动时删除旧状态的键名。
- 已完成规范路径和 Junction/Symlink 边界加固；用户、供应商、助手资源及字体采用持久化补偿事务和严格所有权，资产回填/GC 具备 CAS、账号级 OS 锁、数据库租约、精确隔离凭据和崩溃恢复。
- `flutter gen-l10n` 已执行，四份 ARB 均为 1890 个文案键和 104 个元数据键，`desiredFileName.txt` 为 `{}`；`flutter analyze --no-pub` 通过。
- 全量 `flutter test --no-pub --concurrency=4`：1548 项通过、19 项按平台条件跳过、0 失败。
- Windows Release 与 Android Release 均已重建。Android 包为 `com.psyche.kelivo`、`1.1.17+61`，包含 `arm64-v8a`、`armeabi-v7a`、`x86_64`，使用既有 RSA 4096 密钥通过 APK Signature Scheme v2 验签。
- 发布产物位于 `D:\Projects\Private\kelivo-release-artifacts\1.1.17+61`；Windows ZIP 已通过完整性检查，SHA-256 为 `E6A3CC7962C0B815283E953149C08CB0FCA5DAEF7EDA81E0646D4EA5A0ECCF58`；Android APK 已复验签名，SHA-256 为 `BC2F5F53EC2FD5325B9E4DFD2C3AFC641A89BBAD16934B3DD9E9E0296F40D905`。
- Android Release 构建不得使用 `--no-pub`，否则可能沿用测试阶段生成的 dev 插件注册器；现有六个 Android 工作流均未使用该参数。
- 当前机器未连接 Android 真机，未执行 Android 真机 runner；本机不能覆盖 Linux、macOS、iOS 构建。
- 保留后续 Issue：#2 发布依赖锁定、#3 Drift/Hive 生成器冲突、#4 Android Built-in Kotlin、#7 附件孤儿暂存清理、#8 远端批次异步状态隔离。
- 主工作树中另有其他进程留下的 7 个平台生成文件改动；合并与清理时不得覆盖、暂存或删除。
