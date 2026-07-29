# 协作摘要

- 目标：硬切本地结构化消息附件的读取侧展示、API 构造、mini map 与导出。
- 跟踪：https://github.com/BelovedYaoo/kelivo/issues/50 与 https://github.com/BelovedYaoo/kelivo/issues/52
- 范围：指定读取模块、必要的共享纯 helper 与既有测试；不修改 ChatService、消息生成写侧、home controller、同步适配器或数据库。
- 约束：本地 `[image:path]` / `[file:path|name|mime]` 不再成为附件；远端 URL、HTTPS 与 data URI 的内联媒体语法按现有能力保留。
- 已完成：结构化附件请求投影、聊天气泡顺序展示、移动端与桌面端 mini map、Markdown/TXT/图片导出读取侧硬切。
- 验证：三个相关 Flutter 测试文件共 30 项通过；`flutter analyze lib`、`dart analyze lib` 与三个测试文件的定向分析通过。
- 已知边界：全仓分析仅命中既有 Issue #33；测试发现的默认助手消息模板空断言已另建 Issue #58，本分支未夹带修复。
- 自审：未新增供应商可见内部字段；本地旧标记仅作为正文；远程图片语法保留；导出失败回退不写绝对路径。
