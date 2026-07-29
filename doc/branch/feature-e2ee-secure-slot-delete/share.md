# 协作摘要

- 目标：为安全核心增加本机平台密钥槽主动删除能力，用于本机密码学擦除；普通登出仍保留槽位。
- 分支：`feature/e2ee-secure-slot-delete`，基线为 `feature/e2ee-chat-runtime@0bdb0538`。
- 边界：只修改 `dependencies/kelivo_secure_core` 的原生后端、C ABI/header、Dart 封装和既有测试，不接入上层重置 UI 或业务流程。
- 语义：目标槽位不存在时幂等成功；系统安全存储、权限、认证或删除操作失败时明确失败关闭，不做文件或偏好回退。
- 验收：ABI 各层一致；Windows、Android、iOS、macOS、Linux 已支持后端均有明确删除实现；关闭中的句柄、删除后重开和重复删除由既有测试覆盖。
- 跟踪：https://github.com/BelovedYaoo/kelivo/issues/64；原评论误指向的 #63 实际为 actionlint 基线问题。
