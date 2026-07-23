# Android Release 签名门禁

- 分支：`fix/android-release-signing-guard`
- 基线：`97e8ff8853c35a954853bf5c30ca18cfb1e90957`
- 结果：Release 始终绑定签名配置，并在配置缺失、字段缺失、密钥库不是普通可读文件时于编译前失败。
- 验证：APK 与 AAB Release 均命中门禁；缺少 `keyPassword` 和目录型 `storeFile` 均返回明确错误；Debug 任务图成功且不包含门禁；全仓分析通过。
- 安全：未读取、复制或提交真实 `key.properties`、密钥库、密码和别名。
