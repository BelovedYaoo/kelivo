# 协作记录

## 完成摘要

- scheduler 已支持终止状态、注入式错误判定，以及在途周期清空后的单次回调；终止后不退避、不响应唤醒，回调内可安全关闭 scheduler。
- 生产内容运行时只把不可重试的未认证/禁止访问错误归类为终止认证，网络错误仍退避重试。
- Provider 通过 session epoch 隔离旧 runtime 回调；终止后先持久写入登出 tombstone，再关闭 runtime/ARK，最后释放工作区租约。清理失败仍继续其余步骤、保持已登出事实并暴露错误。
- 未修改聊天消息/仓储、移动注册 UI 或安全核心依赖，无兼容分支或 Timer 规避。

## 验证

- 定向 `dart analyze`：通过。
- 新增终止认证场景：7/7 通过。
- `cloud_sync_provider_content_gate_test.dart`：44/44 通过。
- 清理顺序调整后终止相关场景：6/6 通过。
- Windows Flutter 测试需将 `TEMP/TMP` 指向 `$env:LOCALAPPDATA\Temp`，网络盘临时目录会让 Flutter tool 在 hook 完成后停住。
