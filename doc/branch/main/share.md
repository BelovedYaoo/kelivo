# main 分支协作摘要

- 用途：承载 Kelivo 定制版开发、检查、构建与发布。
- 上游：`upstream` 指向 `Chevey339/kelivo`，其默认分支为 `master`。
- 镜像：`upstream-main` 仅用于对齐 `upstream/master`，不得提交定制内容。
- 当前进度：已建立分支拓扑，并完成 Windows、Android 本机构建环境验收。
- 同步方式：先更新 `upstream-main`，再通过独立同步分支合并到 `main` 并完成验证。
- 构建基线：Flutter `3.44.1`、Dart `3.12.1`、JDK `17.0.16`、Gradle `8.14`、Android SDK `36.1`、NDK `27.0.12077973`、Build Tools `35.0.0`。
- 上游验收：独立 worktree `D:\Projects\Private\kelivo-upstream-build` 固定在 `c8c9ff37c644ab2e121b671fa2628eca1aa88b1e`，已成功构建 Windows Release 和 Android 三 ABI Release。
- 验证结果：`flutter doctor -v` 与 `flutter analyze` 通过；根测试共 770 项，仅 1 项因 Windows 路径分隔符断言失败。
- 发布边界：Android Release 当前未签名；定制版发布前需确定长期签名密钥。用户级 `TEMP/TMP=R:\Temp` 仍需决定是否永久调整为 `%LOCALAPPDATA%\Temp`。
