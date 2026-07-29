# Issue #73 Windows 安全槽重解析点防护

- 完成：Windows 安全槽改为从本地卷根开始，以 `NtCreateFile` 相对父目录句柄逐组件打开或创建，使用 `OBJ_DONT_REPARSE`、`FILE_OPEN_REPARSE_POINT` 和句柄属性复核拒绝所有重解析点。
- 完成：槽读取、临时文件创建、失败清理和删除均绑定已打开句柄；临时文件使用 `NtSetInformationFile(FileRenameInformation)` 在原目录内原子改名，不再以路径重新解析源或目标。
- 覆盖：祖先 junction、`slots` junction、槽文件符号链接、路径被替换后的句柄绑定、临时名称被替换后的按句柄清理、首次目录创建、重复槽和幂等删除。
- 安全边界：本地安全槽只接受本地磁盘根，明确拒绝 UNC/VerbatimUNC；未向 Dart 暴露任何密钥或新接口，未修改 `account_workspace_runtime.dart`。
- 验证：native `cargo fmt --check`、`cargo check --all-targets`、严格 Clippy、61 项测试通过；依赖目录 `flutter analyze` 与 22 项 Flutter 测试通过，并完成 Windows release native 构建。
