# main 分支协作摘要

- 用途：承载 Kelivo 定制版开发、检查、构建与发布。
- 上游：`upstream` 指向 `Chevey339/kelivo`，其默认分支为 `master`。
- 镜像：`upstream-main` 仅用于对齐 `upstream/master`，不得提交定制内容。
- 当前进度：已完成定制界面、私有云同步客户端与生产 API 接入，并建立 Windows、Android 构建及 Android 长期签名基线。
- 定制界面：设置页“关于”分组已移除使用文档与赞助入口；关于详情页仅保留应用信息、版本和系统信息，移动端与桌面端保持一致。
- 同步方式：先更新 `upstream-main`，再通过独立同步分支合并到 `main` 并完成验证。
- 构建基线：Flutter `3.44.1`、Dart `3.12.1`、JDK `17.0.16`、Gradle `8.14`、Android SDK `36.1`、NDK `28.2.13676358`、Build Tools `36.1.0`。
- 上游验收：独立 worktree `D:\Projects\Private\kelivo-upstream-build` 固定在 `c8c9ff37c644ab2e121b671fa2628eca1aa88b1e`，已成功构建 Windows Release 和 Android 三 ABI Release。
- 签名基线：别名 `kelivo-release`，RSA 4096，证书 SHA-256 为 `60C9352840C2C2E3C66ECA19AF9D5C6DFE4A49E75EDB79535B05FE3CC1CC07F3`，有效期至 2053-11-29。
- 签名材料：主密钥位于 `C:\Users\ovo\.kelivo\signing\kelivo-release.jks`；本地 `android/key.properties` 已被 Git 忽略并限制为当前用户访问，协作摘要不得记录密码。
- 最新定制 APK：基于源码提交 `7d9d4a13` 构建通用 Release `1.1.17 (61)`，本地产物为 `build\app\outputs\flutter-apk\app-release.apk`，SHA-256 为 `0B6DFBDF55F2A56B57000EEA585E81D185DDE335273FFF8AD76AD8D27766B2DA`。
- 验证结果：`flutter analyze` 通过；云同步相关测试 20 项全部通过；此前根测试共 790 项，仅 1 项因 Windows 临时目录路径断言失败；最新通用 APK 通过单签名者、v2 签名、ZIP 对齐、版本和三 ABI 校验。
- 兼容边界：定制密钥无法覆盖安装官方签名的 `com.psyche.kelivo`；需先卸载官方版，或另行确认更换自有应用 ID。
- 环境边界：用户级 `TEMP/TMP=R:\Temp` 仍需决定是否永久调整为 `%LOCALAPPDATA%\Temp`。
