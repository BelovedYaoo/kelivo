# main 分支协作摘要

- 用途：承载 Kelivo 定制版开发、检查、构建与发布。
- 上游：`upstream` 指向 `Chevey339/kelivo`，其默认分支为 `master`。
- 镜像：`upstream-main` 仅用于对齐 `upstream/master`，不得提交定制内容。
- 当前进度：已建立分支拓扑，并将 PR 检查目标调整为 `main`。
- 同步方式：先更新 `upstream-main`，再通过独立同步分支合并到 `main` 并完成验证。
