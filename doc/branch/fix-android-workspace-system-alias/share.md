# 协作摘要

- 跟踪：Issue #87，修复 Android 系统 `/data/user/0 -> /data/data` 沙箱别名被安装根校验误拒。
- 基线：`feature/e2ee-chat-runtime@75b0342a`。
- 当前：已在全新 API 36 隔离 AVD 完成红绿验证；公开工作区 bootstrap 从 `account_workspace_installation_root_unsafe` 修复为可正常启动。
- 证据：`app_flutter` 规范路径落到 `/data/data/<package>/app_flutter`，且 `/data/user/0` 为系统 link；现有逐级词法路径相等规则必然拒绝。
- 约束：只接受 Android 固定系统别名；应用可写 symlink、越界路径及非 Android 根链继续失败关闭；不触碰既有 AVD 或 Windows 默认安全槽。
- 实现：仅当 `/data/user/0` 本身为 link 且规范目标精确等于 `/data/data` 时映射后代路径；校验完成后运行时统一持有规范安装根。
- 已验证：Android 合法系统别名、Android 应用可写 symlink 越界拒绝、Windows 祖先/根 junction 拒绝、普通缺失尾部创建、目标文件静态分析均通过。
- 全量工作区测试：111 项通过，3 项命中已关闭 Issue #88 的旧基线问题；主分支 `0bed45c6` 已修复，未在本分支重复修改。
- 后续：提交 #87 修复后，在同一隔离 AVD 完成 #83 未知/合法偏好命名空间及进程重启耐久验证。
