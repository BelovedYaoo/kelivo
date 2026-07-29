# 后台同步 Runner 协作记录

- 分支：`feature/e2ee-background-sync-runner`
- 跟踪：Issue #56
- 完成：实现不依赖 Provider、BuildContext 或 UI 的单次 E2EE 后台同步 Runner，并复用 SQLCipher Vault 与正式同步协议。
- 约束：统一限制总时长、网络步骤与附件密文字节；截止或取消会中止并等待在途网络结算。
- 生命周期：终止认证先持久清除会话，再依次关闭内容运行时、账户租约与工作区租约；取消监听在 Runner 最外层 `finally` 显式解绑。
- 构造安全：内容运行时构造失败会继续关闭已取得的 runtime、client 与账户租约，并保持原始异常和栈。
- 验证：定向分析通过；云同步内容门禁 62 项、数据库约束 86 项通过。全仓库分析仍受既有 Issue #33 阻塞。
- 边界：未修改 Android/iOS，未引入平台调度依赖，未接通知，未修改服务端。
