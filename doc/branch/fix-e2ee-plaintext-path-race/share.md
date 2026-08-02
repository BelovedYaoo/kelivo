# 明文硬切目录换链竞态

## 目标

- 统一消除旧备份临时目录、附件 staging、持久日志和安装级擦除的路径换链竞态。
- Windows、Android、Linux 以目录句柄或目录 FD 约束遍历；Apple 未实现等价原语时失败关闭。

## 进度

- 已兼容 Android `/data/user/0` 的现代 bind mount 与旧 symlink：bind 形态必须与 `/data/data` 为同一对象且 `mnt_id` 不同，symlink 形态必须精确指向规范目标。
- 原生托管根目录会话核心已完成：仅暴露旧备份、附件 staging、持久日志和安装目录擦除四个固定操作。
- Windows 使用相对目录句柄并固定整条祖先链；Linux 保留 `openat2`；Android 仅使用 `openat(O_NOFOLLOW)` 与 fdinfo `mnt_id`，拒绝同设备的后代 bind mount；Apple 失败关闭。
- API 36 AVD 实测 `/data` 与 `/data/user/0` 分别为 `mnt_id` 113/230，且同为设备 `254:55`。修复前能力探测触发 syscall 437，被 seccomp 以 `SIGSYS` 杀死；修复版 APK 可安装并运行 30 秒无该崩溃。
- Linux 受管根测试 21/21、Android x86_64 严格 Clippy 通过；显式 `/data/user/0/...` 公开 ABI 集成用例已加入，但 Flutter/Gradle 完成 APK 后宿主交接卡住，未取得该用例的最终断言回传。
- 正在拆分 C ABI、Dart 封装和四个生产调用点；当前分支 ABI 暂定 19，最终集成需与恢复介质分支顺延合并。
- 应用层已接入同一安装根会话：本地擦除不再传根路径，数据库门禁每次准入都调用固定附件退役操作，后台生命周期显式关闭会话。
- 旧备份退役已移除 Dart 目录遍历，改由系统临时根会话执行固定白名单操作；持久日志调用点由 #84 在同一会话上接入。
- 相关 Flutter 测试 66/66 通过，`flutter analyze --no-pub lib test` 通过；无范围分析仍受 path dependency 既有开发依赖缺失阻断。

## 约束

- 不访问默认安全槽。
- 不保留 Dart 路径递归兼容回退，不忽略删除和耐久确认错误。
- 如确认必须新增原生 ABI 或改变平台兼容语义，先向主任务报告。
