# 明文硬切目录换链竞态

## 目标

- 统一消除旧备份临时目录、附件 staging、持久日志和安装级擦除的路径换链竞态。
- Windows、Android、Linux 以目录句柄或目录 FD 约束遍历；Apple 未实现等价原语时失败关闭。

## 进度

- 原生托管根目录会话核心已完成：仅暴露旧备份、附件 staging、持久日志和安装目录擦除四个固定操作。
- Windows 使用相对目录句柄并固定整条祖先链；Android/Linux 使用目录 FD、`openat2`/`unlinkat` 并复核对象身份；Apple 失败关闭。
- Windows 原生测试 89/89 通过，Windows/Linux 严格 Clippy 与 Linux/Android 交叉编译通过。
- 正在拆分 C ABI、Dart 封装和四个生产调用点；当前分支 ABI 暂定 19，最终集成需与恢复介质分支顺延合并。

## 约束

- 不访问默认安全槽。
- 不保留 Dart 路径递归兼容回退，不忽略删除和耐久确认错误。
- 如确认必须新增原生 ABI 或改变平台兼容语义，先向主任务报告。
