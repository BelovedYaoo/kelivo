# 恢复检查点 v6 协作记录

- 状态：已完成，待合并。
- 结果：检查点硬切为 v6 单阶段判别模型，覆盖 direct replacement 与 resume 后第二挑战链路；所有耐久阶段均可加密落盘并重开。
- 安全：严格持有 260 字节 Native opaque continuation，移动、激活、拒绝及解码异常时清零；首轮本地激活后裁剪大 manifest、状态 blob 与 continuation。
- 格式：使用稳定显式阶段编号和严格二进制 codec；v5 硬拒绝；最大 manifest/capsule 下密文帧小于 64 KiB。
- 验证：四个恢复相关测试文件经 secure wrapper 共 31 个场景通过；四个变更 Dart 文件定向 `flutter analyze` 通过。
- 边界：未修改 Native、Runner、Provider、API 或生成的插件注册文件。
